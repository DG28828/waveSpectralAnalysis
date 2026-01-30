function [I, W] = wsa_psdwb(X, ventana, varargin)
%wsa_psdwb - densidad espectral de potencia mediante el método de Welch-Barlett.
%
%   Esta función realiza la estimación de la densidad espectral de potencia 
%   de X mediante el método de Welch-Barlett.
%   Si se especifica Y, se calcula la densidad espectral de potencia cruzada 
%   de X e Y.
%
%   Sintaxis:
%       I = wsa_psdwb(X, ventana)
%       I = wsa_psdwb(X, ventana, 'Y', Y)
%       I = wsa_psdwb(X, ventana, 'N', N)
%       I = wsa_psdwb(X, ventana, 'N', N, 'N0', N0)
%       I = wsa_psdwb(X, ventana, 'K', 'Nfft')
%       I = wsa_psdwb(X, ventana, 'K', K, 'N0', N0)
%       I = wsa_psdwb(X, ventana, 'K', K, 'N', N, 'N0', N0, 'Nfft', Nfft, 'Y', Y, 'pc', 1)
%
%
%       [I, W] = wsa_psdwb(X, ventana)
%       [I, W] = wsa_psdwb(X, ventana, 'Y', Y)
%       [I, W] = wsa_psdwb(X, ventana, 'N', N)
%       [I, W] = wsa_psdwb(X, ventana, 'N', N, 'N0', N0)
%       [I, W] = wsa_psdwb(X, ventana, 'K', 'Nfft')
%       [I, W] = wsa_psdwb(X, ventana, 'K', K, 'N0', N0)
%       [I, W] = wsa_psdwb(X, ventana, 'K', K, 'N', N, 'N0', N0, 'Nfft', Nfft, 'Y', Y, 'pc', 1)
%
%   Argumentos de entrada:
%       X - Arreglo de entrada X 
%           vector
%       N - Longitud del segmento
%           entero | (opcional) Por defecto: N = 2*M/(K+1) 
%       N0 - Longitud del solapamiento entre los segmentos
%           entero (opcional) Por defecto: N0 = N/2  (50 %)
%       ventana - ventana a emplear 
%           string ("rectangular", "hann", "hamming")
%       M - Longitud de la secuencia de entrada 
%           entero | (opcional) Por defecto: M = longitud de X
%       K - Número de segmentos
%           entero | (opcional) Por defecto K = (M-N0)/(N-N0)
%       Nfft - Longitud del periodograma del segmento
%           entero (potencia de 2) | (opcional) Por defecto: máximo entre
%           la potencia de 2 mayor mas cercana a N y 512.
%       Y - Arreglo de entrada Y 
%           vector | (opcional) Por defecto: []
%       pc - Bandera para imprimir en consola (print consle): brinda
%       información acerca de modificaciones en valores de M, N, N0, K, Nfft
%           bool | (opcional) Por defecto: 0
%
%   Argumentos de salida:
%       I - Estimador del espectro de potencia 
%           vector
%       W - Frecuencias angulares 
%           vector
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 28/01/2026
% Fecha de modificación: 30/01/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
M_default = length(X);                          %Por defecto M es la longitud de X
K_default = 8;                                  %Por defecto K = 8 para que sean 16 GDL
M_new = M_default;
while mod(2*M_new/(K_default+1), 1) ~= 0
    M_new = M_new-1;
end
M_default = M_new;                              %Modificar M para que N = 2M/(K+1) sea entero
N_default = 2*M_default/(K_default+1);          %N = 2M/(K+1) hace que K = (M-N0)/(N-N0) sea entero cuando N0 = N/2
N0_default = N_default/2;                       %Hacer que N0 = N/2
Nfft_default = max(512, 2^nextpow2(N_default));
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'X');
addRequired(p, 'ventana');

addParameter(p, 'N', N_default);
addParameter(p, 'N0', N0_default);
addParameter(p, 'M',    M_default);
addParameter(p, 'K',    K_default);
addParameter(p, 'Nfft', Nfft_default);
addParameter(p, 'Y',    []);
addParameter(p, 'pc',    pc_default);

parse(p, X, ventana, varargin{:});

%Resultados
M    = p.Results.M;
N    = p.Results.N;
N0   = p.Results.N0;
K    = p.Results.K;
Nfft = p.Results.Nfft;
Y    = p.Results.Y;
pc   = p.Results.pc;

espectro_cruzado = ~isempty(Y);


%% Verificaciones iniciales

%Verificar tamaños consistentes entre X e Y
if ~isempty(Y) && length(Y) ~= length(X)
    error('X e Y deben tener la misma longitud para el cálculo de la densidad espectral cruzada');
end

%Verificar que X e Y son vector columna
if size(X, 1) ~= length(X)
    X = X';
end
if ~isempty(Y)
    if size(Y, 1) ~= length(Y)
        Y = Y';
    end
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
    if pc
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
                if pc
                    fprintf('    M = %d\n', M)
                end
            else 
                %%%%% Caso: 'K', 'N' %%%%%
                % Acciones: 
                %   1) Hacer N0 = N/2
                %   2) Recortar M tal que M = K(N-N0)+N0
                N0 = floor(N/2);               
                M = K*(N-N0)+N0;         
                if pc
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
                if pc
                    warning('    M = %d\n', M)
                    warning('    N = %d\n', N)
                    warning('    Nfft = %d\n', Nfft)
                end
            else
                %%%%% Caso: 'K', %%%%%
                % Acciones:
                %   1) Ajustar M tal que cumpla que N = 2*M/(K+1) es entero
                %   2) Hacer N = 2*M/(K+1)
                %   3) Hacer N0 = N/2
                M_new = M;
                while mod(2*M_new/(K+1), 1) ~= 0
                    M_new = M_new-1;
                end
                M = M_new;                  
                N = 2*M/(K+1);              
                N0 = floor(N/2);                   
                Nfft = max([Nfft, 512, 2^nextpow2(N)]); 
                if pc
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
        if pc
            warning('Los parámetros ingresados no cumplen con la razón (M-N0)/(N-N0) que sea un número entero, se ajustó el valor de M a M = %d', M)
        end
    end
    % hacer coincidir K con la relación (M-N0)/(N-N0)
    if K ~= razon
        K = floor(razon);
        M = K*(N-N0) + N0;
        if pc
            warning('El valor de K no es tal que K = (M-N0)/(N-N0) es entero. Se ajustó el valor a K = %d', K)
            warning('Se ajustó el valor de M a M = %d', M)
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
        if pc
            warning('Se especificó un valor de M mayor a la longitud de X e Y,  haciendo M = %d', M)
        end
    end
elseif M < X_length
    if isempty(Y)
        if pc
            warning('El valor de M es menor a la longitud de X, recortando los valores correspondientes de X')
        end
        X = X(1:M);
    else
        if pc
            warning('El valor de M es menor a la longitud de X e Y, recortando los valores correspondientes de X e Y')
        end
        X = X(1:M);
        Y = Y(1:M);
    end
end

%Imprimir parámetros resultantes
if pc
    fprintf('Parámetros resultantes\n\tM = %d\n\tN = %d\n\tN0 = %d\n\tK = %d\n\tNfft = %d\n\n', M, N, N0, K, Nfft)
end
%% Constante de normalización U
% Esta constante se emplea para normalizar la energía de la ventana de
% forma que el periodograma resultante sea asintóticamente insesgado.
%
% Calculado de acuerdo con (10.64) de (Oppenheim, A. V., 2000), pag 736.

% Ventana de longitud N
switch lower(string(ventana))
    case "rectangular"
        w = rectwin(N);
    case "hann"
        w = hanning(N);
    case "hamming"
        w = hamming(N);
    otherwise
        error('Debe especificar alguna de las siguientes ventanas: "rectangular", "hann", "hamming"')
end
U = mean(w.^2);

%% Método de Welch-Barlett
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
        [H_r, W] = wsa_dft(x_r, Nfft);
        I_n = (1/(N*U))*abs(H_r).^2;
       
        I_acum = I_acum + I_n;
    end
else
    for r = 1:K
    
        % Señales enventanadas
        x_r = X((r-1)*R+1:(r-1)*R+N).*w;
        y_r = Y((r-1)*R+1:(r-1)*R+N).*w;
    
        % Periodogramas
        [H_x_r, W] = wsa_dft(x_r, Nfft);
        [H_y_r, ~] = wsa_dft(y_r, Nfft);
    
        I_xy_n = (1/(N*U))*H_x_r.*conj(H_y_r);
       
        I_acum = I_acum + I_xy_n;
    end
end

I = I_acum./K;   % Periodograma promedio