function [H, W] = wsa_dft(h, Nfft)
%wsa_dft - Transformada Discreta de Fourier (Discrete Fourier Transform)
%
%   Esta función calcula la transformada discreta de Fourier de h por medio
%   de una llamada a la función fft de MATLAB, el cual emplea el algoritmo
%   de la Transformada Rápida de Fourier (FFT).
%
%   Sintaxis:
%       H = wsa_dft(h)
%       H = wsa_dft(h, Nfft)
%
%       [H, W] = wsa_dft(h)
%       [H, W] = wsa_dft(h, Nfft)
%
%   Argumentos de entrada:
%       h - arreglo de entrada (vector | matriz) (secuencias en columnas en caso de matriz)
%       Nfft - número de frecuencias para evaluar la fft
%               Nfft >= N     (N: longitud de h)
%
%   Argumentos de salida:
%       H - valores de la dft (números complejos)
%       W - vector de frecuencia angular digital (rad/muestra) [-pi,pi)
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 28/01/2026
% Fecha de modificación: 17/04/2026
% -------------------------------------------------------------------------

%% Verificaciones iniciales

%Verificar existencia de Nfft
if ~exist('Nfft', 'var') || isempty(Nfft)
    %Si no existe, asignar la potencia de 2 mayor mas cercana length(h).
    if isvector(h)
        Nfft = 2^nextpow2(numel(h));
    else
        Nfft = 2^nextpow2(size(h,1));
    end
end

% Si h es vector fila, convertirlo a columna
if isvector(h)
    h = h(:);
end

% Verificar que h sea 2D
if ~isvector(h) && ~ismatrix(h)
    error('La entrada h debe ser un vector o una matriz 2D');
end

N = size(h, 1);

%Verificar que Nfft >= N
Nfft = fix(Nfft);    %Hacer Nfft entero
if( Nfft < N )
   error('El número de frecuencias Nfft debe ser mayor a la longitud de la secuencia de entrada h')
end


%% Cálculo de la fft
n = (0:Nfft-1)';
W = (2*pi/Nfft)*n';                 %Arreglo de frecuencias [0,2pi)
mid = ceil(Nfft/2) + 1;             %Mitad del areglo
W(mid:Nfft) = W(mid:Nfft) - 2*pi;   %Frecuencias [pi,2pi)
W = fftshift(W);                    %Mueve [pi,2pi) to [-pi,0)
H = fftshift(fft(h, Nfft, 1), 1);         %Calcula fft y mueve las componentes

end

