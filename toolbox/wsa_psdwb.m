function [I, W] = wsa_psdwb(X, N, N0, ventana, varargin)
%wsa_psdwb - densidad espectral de potencia mediante el método de Welch-Barlett.
%
%   Esta función realiza la estimación de la densidad espectral de potencia 
%   de X mediante el método de Welch-Barlett.
%   Si se especifica Y, se calcula la densidad espectral de potencia cruzada 
%   de X e Y.
%
%   Sintaxis:
%       I = wsa_wbpsd(X, N, N0, ventana)
%       I = wsa_wbpsd(X, N, N0, ventana, 'M', M, 'K', K, 'Nfft', Nfft, 'Y', Y)
%
%       [I, W] = wsa_wbpsd(X, N, N0, ventana)
%       [I, W] = wsa_wbpsd(X, N, N0, ventana, 'M', M, 'K', K, 'Nfft', Nfft, 'Y', Y)
%
%   Argumentos de entrada:
%       X - Arreglo de entrada X 
%           vector
%       N - Longitud del segmento
%           entero (potencia de 2)
%       N0 - Longitud del solapamiento entre los segmentos
%           entero
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
% Fecha de modificación: 28/01/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
M_default = length(X);
K_default = floor((M_default - N0)/(N - N0));
Nfft_default = max(512, 2^nextpow2(N));

%Input parser
p = inputParser;

addRequired(p, 'X');
addRequired(p, 'N');
addRequired(p, 'N0');
addRequired(p, 'ventana');

addParameter(p, 'M',    M_default);
addParameter(p, 'K',    K_default);
addParameter(p, 'Nfft', Nfft_default);
addParameter(p, 'Y',    []);

parse(p, X, N, N0, ventana, varargin{:});

%Resultados
M    = p.Results.M;
K    = p.Results.K;
Nfft = p.Results.Nfft;
Y    = p.Results.Y;

espectro_cruzado = ~isempty(Y);

%% Verificaciones iniciales

%Verificar que X es vector columna
[row_size, ~] = size(X);
X_length = length(X);
if row_size ~= X_length
    X = X';
end

% Consistencia entre M y tamaño de X
if M > X_length
    M = X_length;
    warning('Se especificó un valor de M mayor a la longitud de X,  haciendo M = %d', M)
elseif M < X_length
    warning('Se especificó un valor de M menor a la longitud de X, recortando los valores correspondientes de X')
    %X = zeros(M, 1);
    X = X(1:M);
end

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
    %X = zeros(M, 1);
    X = X(1:M);
    warning('Los parámetros ingresados no cumplen con la razón (M-N0)/(N-N0) que sea un número entero, se ajustó el valor de M a M = %d y se recortaron los datos correspondientes', M)
end

% hacer coincidir K con la relación (M-N0)/(N-N0)
if K ~= razon
    K = razon;
    warning('El valor de K especificado no cumple K = (M-N0)/(N-N0). Se ajustó el valor a K = %d', K)
end

%% Constante de normalización U
% Esta constante se emplea para normalizar la energía de la ventana de
% forma que el periodograma resultante sea asintóticamente insesgado.
%
% Calculado de acuerdo con (10.64) de (Oppenheim, A. V., 2000), pag 736.

% Ventana de longitud N
w = zeros(N, 1);    %inicialzar variable
if ventana == "rectangular"
    w(1:end) = rectwin(N);
elseif ventana == "hann"
    w(1:end) = hanning(N);
elseif ventana == "hamming"
    w(1:end) = hamming(N);
else
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