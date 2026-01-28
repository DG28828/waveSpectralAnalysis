function [H, W] = wsa_dft(h, Nfft)
%wsa_dft - Transformada Discreta de Fourier (Discrete Fourier Transform)
%   Esta función calcula la transformada discreta de Fourier de x por medio
%   de una llamada a la función fft de MATLAB, el cual emplea el algoritmo
%   de la Transformada Rápida de Fourier (FFT).
%
%   Sintaxis:
%       H = wsa_dtft(h)
%       H = wsa_dtft(h, Nfft)
%
%       [H, W] = wsa_dft(h, Nfft)
%       [H, W] = wsa_dft(h, Nfft)
%
%   Argumentos de entrada:
%       h - arreglo de entrada (vector)
%       Nfft - número de frecuencias para evaluar la fft
%               Nfft >= N     (N: longitud de h)
%
%   Argumentos de salida:
%       H - valores de la dft (números complejos)
%       W - vector de frecuencias [-pi,pi)
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 28/01/2026
% Fecha de modificación: 28/01/2026
% -------------------------------------------------------------------------

%% Verificaciones iniciales

%Verificar que Nfft >= N
Nfft = fix(Nfft);    %Hacer Nfft entero
N = length(h);
if( Nfft < N )
   error('El número de frecuencias Nfft debe ser mayor a la longitud de la secuencia de entrada h')
end

%Verificar que h es vector columna
[row_size, ~] = size(h);
if row_size ~= N
    h = h';
end

%% Cálculo de la fft
n = 0:1:(Nfft-1);
W = (2*pi/Nfft)*n';                 %Arreglo de frecuencias [-pi,pi)
mid = ceil(Nfft/2) + 1;             %Mitad del areglo
W(mid:Nfft) = W(mid:Nfft) - 2*pi;   %Frecuencias [pi,2pi)
W = fftshift(W);                    %Mueve [pi,2pi) to [-pi,0)
H = fftshift(fft(h, Nfft));         %Calcula fft y mueve las componentes

end

