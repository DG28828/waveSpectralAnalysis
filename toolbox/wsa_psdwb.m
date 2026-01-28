function [Ixy, W] = wsa_psdwb(X, Y, M, N0, K, N, ventana, Nfft)
%wbpcsd - densidad espectral de potencia cruzada mediante método de Welch-Barlett.
%
% Esta función realiza la estimación espectral cruzada de X e Y mediante la técnica de
% Welch-Barlett.
%
% Sintaxis:
% [PSD, W] = wbpsd(X, Y, M, N0, K, N, ventana, Nfft)
%
% Argumentos de entrada:
%   X - Arreglo de entrada X (vector)
%   Y - Arreglo de entrada Y (vector)
%   M - Longitud de la secuencia de entrada (entero)
%   N0 - Longitud del solapamiento entre los segmentos
%   K - Número de segmentos
%   N - Longitud del segmento (entero potencia de 2)
%   ventana - ventana a emplear (rectangular, von Hann, Hanning)
%   Nfft - Longitud del periodograma del segmento (por defecto Nfft = 512)
%
% Argumentos de salida
% I - Estimador del espectro de potencia (vector)
% W - Frecuencias angulares (vector)
% 

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

I_xy_acum = zeros(Nfft, 1);

R = N-N0;
for r = 1:K

    % Señales enventanadas
    x_r = X((r-1)*R+1:(r-1)*R+N).*w;
    y_r = Y((r-1)*R+1:(r-1)*R+N).*w;

    % Periodogramas
    [H_x_r, W] = dtft(x_r, Nfft);
    [H_y_r, ~] = dtft(y_r, Nfft);

    I_xy_n = (1/(N*U))*H_x_r.*conj(H_y_r);
   
    I_xy_acum = I_xy_acum + I_xy_n;
end

Ixy = I_xy_acum./K;   % Periodograma promedio