function [out, info] = wsa_psdwb(X, window, varargin)
%wsa_psdwb - densidad espectral de potencia mediante el método de Welch-Bartlett.
%
%   Esta función realiza la estimación de la densidad espectral de potencia 
%   de X mediante el método de Welch-Bartlett.
%   Si se especifica Y, se calcula la densidad espectral de potencia cruzada 
%   de X e Y. La convención empleada para la densidad espectral de potencia
%   cruzada es la dada por (Ochi, 1998).
%                           
%
%   Sintaxis:
%       out = wsa_psdwb(X, window) estima la densidad espectral de potencia
%           (PSD) de la señal X utilizando el método de Welch-Bartlett.
%
%       [out, info] = wsa_psdwb(X, window) devuelve adicionalmente una estructura
%           info con los parámetros finales utilizados en el cálculo.
%
%       out = wsa_psdwb(X, window, 'Y', Y) estima la densidad espectral de potencia
%           cruzada entre X e Y. La convención empleada es:
%
%                       I_xy[k] = conj(X[k]) · Y[k]
%
%           donde X[k] y Y[k] son las DFT de los segmentos enventanados.
%
%
%   Argumentos de entrada (requeridos):
%       X       - Señal de entrada.
%                   Vector columna o fila.
%
%       window - Tipo de ventana a emplear.
%                   "rectangular" | "hann" | "hamming"
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'N'     - Longitud del segmento.
%                   Entero par.
%                   Por defecto: N = 2*M/(K+1)
%
%       'N0'    - Longitud del solapamiento entre segmentos.
%                   Entero.
%                   Por defecto: N0 = N/2  (50%)
%
%       'M'     - Longitud efectiva de la secuencia.
%                   Entero.
%                   Por defecto: M = longitud ajustada de X.
%
%       'K'     - Número de segmentos.
%                   Entero positivo.
%                   Por defecto: K = 8  (16 grados de libertad).
%                   Por defecto K = (M-N0)/(N-N0) (Si se especifica M, N o N0)
%
%       'Nfft'  - Longitud de la DFT de cada segmento.
%                   Entero (potencia de 2).
%                   Por defecto: max(512, 2^nextpow2(N)).
%
%       'Y'     - Segunda señal para espectro cruzado.
%                   Vector del mismo tamaño que X.
%                   Por defecto: []
%
%       'printFlag' - Bandera para imprimir. Muestra los ajustes automáticos de parámetros.
%                   true | false
%                   Por defecto: false
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       I           - Estimador de la densidad espectral
%                   [unidad de X]^2 / rad/muestra
%       W           - Frecuencias angulares digitales (rad/muestra)
%
%   info        - Estructura con los parámetros finales utilizados:
%                   M, N, N0, K, Nfft, DoF, window
%
%
%   Notas:
%   • El estimador se normaliza mediante la constante U = mean(w.^2)
%     para garantizar insesgamiento asintótico.
%   • Si los parámetros no son consistentes, la función ajusta
%     automáticamente M, N, N0 o K para cumplir:
%
%         K = (M - N0)/(N - N0)
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 28/01/2026
% Fecha de modificación: 15/05/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
M_default = length(X);                          %Por defecto M es la longitud de X
K_default = 8;                                  %Por defecto K = 8 para que sean 16 GDL
M_new = M_default;
while true                                      %Este ciclo asegura N entero par
    N_i = 2*M_new/(K_default+1);
    if mod(N_i,1)==0 && mod(N_i,2)==0
        break
    end
    M_new = M_new - 1;
end
M_default = M_new;                              %Modificar M para que N = 2M/(K+1) sea entero
N_default = 2*M_default/(K_default+1);          %N = 2M/(K+1) hace que K = (M-N0)/(N-N0) sea entero cuando N0 = N/2
N0_default = N_default/2;                       %Hacer que N0 = N/2
Nfft_default = max(512, 2^nextpow2(N_default));
printFlag_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'X');
addRequired(p, 'window');

addParameter(p, 'N', N_default);
addParameter(p, 'N0', N0_default);
addParameter(p, 'M',    M_default);
addParameter(p, 'K',    K_default);
addParameter(p, 'Nfft', Nfft_default);
addParameter(p, 'Y',    []);
addParameter(p, 'printFlag',    printFlag_default);

parse(p, X, window, varargin{:});

%Resultados
M    = p.Results.M;
N    = p.Results.N;
N0   = p.Results.N0;
K    = p.Results.K;
Nfft = p.Results.Nfft;
Y    = p.Results.Y;
printFlag   = p.Results.printFlag;

espectro_cruzado = ~isempty(Y);


%% Verificaciones iniciales

%Verificar tamaños consistentes entre X e Y
if ~isempty(Y) && length(Y) ~= length(X)
    error('X e Y deben tener la misma longitud para el cálculo de la densidad espectral cruzada');
end

%Verificar que X e Y son vector columna
if ~isvector(X)
    error('X debe ser un vector fila o columna.');
end
X = X(:);

if ~isempty(Y)
    if ~isvector(Y)
        error('Y debe ser un vector fila o columna.');
    end
    Y = Y(:);
end

if mod(N0,1) ~= 0
    error('N0 debe ser entero.');
end

%Verificar tamaños de entradas opcionales
if N~=N_default && N>M
    error('N no puede ser mayor que M')
elseif N~=N_default && mod(N, 2) ~= 0
    error('N debe ser un múltiplo de 2')
elseif N0~=N0_default && N0>N
    error('N0 no puede ser mayor que N')
end



%% Actualización de parámetros para consistencia de los cálculos y prioridades
%Modificar resultados de acuerdo a prioridades de parametros introducidos
%Prioridades:
%   1) Valor de K es prioritario, si se especifica, los valores de M, N y N0
%       resultantes dependerán si además se especifica N, N0 o ambos.

if K~=K_default
    if printFlag
        fprintf('Especificado valor de K, ajustando los demás parámetros:\n')
    end
    if K < 1
        error('K no puede ser menor a 1')
    else
        if N ~= N_default
            if N0 ~= N0_default
                %%%%% Caso: 'K', 'N', 'N0' %%%%%
                % Acciones: 
                %   1) Recortar M tal que M = K(N-N0)+N0
                M = K*(N-N0)+N0;         
                if printFlag
                    fprintf('    M = %d\n', M)
                end
            else 
                %%%%% Caso: 'K', 'N' %%%%%
                % Acciones: 
                %   1) Hacer N0 = N/2
                %   2) Recortar M tal que M = K(N-N0)+N0
                N0 = N/2;               
                M = K*(N-N0)+N0;         
                if printFlag
                    fprintf('    M = %d\n', M)
                    fprintf('    N0 = %d\n', N0)
                end
            end
        else %N == N_default
            if N0 ~= N0_default
                %%%%% Caso: 'K', 'N0' %%%%%
                % Acciones:
                %   1) Ajustar M tal que cumpla que N = (M - N0 + K*N0)/(K) es entero
                %   2) Hacer N = (M - N0 + K*N0)/(K)
                M_new = M;
                while mod((M_new - N0 + K*N0)/(K), 1) ~= 0
                    M_new = M_new-1;
                end
                M = M_new;                  
                N = (M - N0 + K*N0)/(K);    
                Nfft = max([Nfft, 512, 2^nextpow2(N)]); 
                if printFlag
                    fprintf('    M = %d\n', M)
                    fprintf('    N = %d\n', N)
                    fprintf('    Nfft = %d\n', Nfft)
                end
            else
                %%%%% Caso: 'K', %%%%%
                % Acciones:
                %   1) Ajustar M tal que cumpla que N = 2*M/(K+1) es entero
                %   2) Hacer N = 2*M/(K+1)  (Asegurando que N sea par)
                %   3) Hacer N0 = N/2       (Al asegurar N par, entonces N0 es entero)
                M_new = M;
                while true
                    N_i = 2*M_new/(K+1);
                    if mod(N_i, 1) == 0 && mod(N_i, 2) == 0  % Asegurar N par
                        break
                    end
                    M_new = M_new - 1;
                end
                M = M_new;                  
                N = 2*M/(K+1);              
                N0 = N/2;                   
                Nfft = max([Nfft, 512, 2^nextpow2(N)]); 
                if printFlag
                    fprintf('    M = %d\n', M)
                    fprintf('    N = %d\n', N)
                    fprintf('    N0 = %d\n', N0)
                    fprintf('    Nfft = %d\n', Nfft)
                end
            end            
        end
    end
else %K = K_default
    % Verificar tamaño completo de los segmentos especificados
    % Se reduce el valor de M hasta que se cumpla que la razón (M-N0)/(N-N0) es
    % un número entero
    razon = (M-N0)/(N-N0);
    M_new = M;
    while mod(razon, 1) ~= 0
        M_new = M_new-1;
        razon = (M_new-N0)/(N-N0);
    end
    if M ~= M_new
        M = M_new; 
        if printFlag
            fprintf('Los parámetros ingresados no cumplen con la razón (M-N0)/(N-N0) que sea un número entero, se ajustó el valor de M a M = %d\n', M)
        end
    end
    % hacer coincidir K con la relación (M-N0)/(N-N0)
    if K ~= razon
        K = floor(razon);
        M = K*(N-N0) + N0;
        if printFlag
            fprintf('El valor de K no es tal que K = (M-N0)/(N-N0) es entero. Se ajustó el valor a K = %d\n', K)
            fprintf('Se ajustó el valor de M a M = %d\n', M)
        end
    end
end


% Consistencia entre M y tamaño de X e Y
% Esta es la última verificación en la que se modifican los arreglos X e Y
% dependiendo del valor resultante de M de las verificaciones anteriores.
% Se recortan los valores de X e Y correspondientes desde el final.
X_length = length(X);
if M > X_length
    if isempty(Y)
        error('El valor de M resultante para los parámetros proporcionados es mayor a la longitud del arreglo, se requiere M = %d y se está proporcionando un arreglo de tamaño M = %d', M, X_length)
    else
        error('Se especificó un valor de M mayor a la longitud de X e Y, se requiere M = %d y se está proporcionando un arreglo de tamaño M = %d', M, X_length)
    end
elseif M < X_length
    if isempty(Y)
        if printFlag
            fprintf('El valor de M es menor a la longitud de X, recortando los valores correspondientes de X\n')
        end
        X = X(1:M);
    else
        if printFlag
            fprintf('El valor de M es menor a la longitud de X e Y, recortando los valores correspondientes de X e Y\n')
        end
        X = X(1:M);
        Y = Y(1:M);
    end
end

%Imprimir parámetros resultantes
if printFlag
    fprintf('Parámetros resultantes\n\tM = %d\n\tN = %d\n\tN0 = %d\n\tK = %d\n\tNfft = %d\n\n', M, N, N0, K, Nfft)
end

%% Constante de normalización U
% Esta constante se emplea para normalizar la energía de la ventana de
% forma que el periodograma resultante sea asintóticamente insesgado.
%
% Calculado de acuerdo con (10.64) de (Oppenheim, A. V., 2000), pag 736.

% Ventana de longitud N
switch lower(string(window))
    case "rectangular"
        w = rectwin(N);
    case "hann"
        w = hann(N);
    case "hamming"
        w = hamming(N);
    otherwise
        error('Debe especificar alguna de las siguientes ventanas: "rectangular", "hann", "hamming"')
end
U = mean(w.^2);

%% Método de Welch-Bartlett
% Para la secuencia de datos x[n] definida en 0<=n<=(M-1), se divide en
% K segmentos de N muestras y se aplica a cada segmento una ventana de
% longitud L. Se forman los segmentos x_r[n] = x[r*R + n], 0<=n<=(N-1)
%
% Para obtener cada segmento se aplica una ventana w_r[n] de longitud M, 
% cuyos valores son distintos de cero en r*R<=n<=(r*R+(N-1)) y cero en el
% resto.
%
% El codigo mostrado a continuación emplea esto ajustado a los índices de
% MATLAB (comenzando en 1).

I_acum = zeros(Nfft, 1);
R = N-N0;

if ~espectro_cruzado
    for r = 1:K

        % Señal enventanada
        x_r = X((r-1)*R+1:(r-1)*R+N).*w;

        % Periodograma
        if r == 1
            [H_r, W] = wsa_dft(x_r, Nfft);
        else
            [H_r, ~] = wsa_dft(x_r, Nfft);
        end
        I_n = (1/(N*U))*abs(H_r).^2;

        I_acum = I_acum + I_n;
    end
else
    for r = 1:K

        % Señales enventanadas
        x_r = X((r-1)*R+1:(r-1)*R+N).*w;
        y_r = Y((r-1)*R+1:(r-1)*R+N).*w;

        % Periodogramas
        if r == 1
            [H_x_r, W] = wsa_dft(x_r, Nfft);
        else
            [H_x_r, ~] = wsa_dft(x_r, Nfft);
        end
        [H_y_r, ~] = wsa_dft(y_r, Nfft);

        I_xy_n = (1/(N*U))*conj(H_x_r).*H_y_r;

        I_acum = I_acum + I_xy_n;
    end
end

I = I_acum./K;   % Periodograma promedio


%% Cálculos adicionales

if espectro_cruzado
    phi_XY = unwrap(angle(I));
end

%% Guardar resultados

%Struct para resultados
out = struct;
out.I = I;
out.W = W;
if espectro_cruzado
    out.phase = phi_XY;
end

%Guardar parámetros empleados
info = struct;
info.M = M;
info.N = N;
info.N0 = N0;
info.K = K;
info.Nfft = Nfft;
info.DoF = 2*K;
info.window = window;

end