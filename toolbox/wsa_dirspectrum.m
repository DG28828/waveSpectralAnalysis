function [E, f, theta] = wsa_dirspectrum(eta, u, v, fs)
%wsa_dirmem - espectro de energía direccional
%
%   Esta función estima el espectro de energía direccional a partir de 
%   datos derivados de mediciones PUV (presión y velocidades orbitales) a 
%   partir de de un registro de mediciones de superficie libre (eta). Los 
%   datos de entrada deben estar ubicados en superficie y adecuadamente 
%   corregidos hidrodinámicamente.
% 
%   La distribución direccional se estima empleando el método de máxima
%   entropía de (Lygre & Krogstad, 1986) (referirse a la función wsa_dirmem)
%   y los coeficientes de la serie de Fourier implicados en el cálculo se 
%   estiman por el método de (Longuet-Higgins et al., 1963) (referirse a 
%   la función wsa_puvcoeffs). Las densidades espectrales cruzadas se
%   estiman empleano el método de Welch.
%
%   Sintaxis:
%
%
%   Argumentos de entrada:
%       eta - secuencia de superficie libre 
%           vector
%       u - secuencia de velocidades orbitales en X
%           vector
%       v - secuencia de velocidades orbitales en Y
%           vector
%       fs - frecuencia de muestreo (Hz)
%           entero
%
%   Argumentos de salida:
%       E - Valores de energía ([unidades de eta]^2/Hz/°)
%           vector
%       f - frecuencias físicas (Hz)
%           vector
%       theta - Angulos (°)
%           vector
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 04/02/2026
% Fecha de modificación: 04/02/2026
% -------------------------------------------------------------------------

%%

%Espectro frecuencial
[S, f] = wsa_spectrum(eta, fs);

%Coeficientes de la serie de Fourier
coeffs = wsa_puvcoeffs(eta, u, v);

%Función de distribución direccional
d1 = coeffs.a1;
d2 = coeffs.a2;
d3 = coeffs.b1;
d4 = coeffs.b2;
Ntheta = 360/2;
[D, theta] = wsa_dirmem(d1, d2, d3, d4, Ntheta);

% Espectro direccional
E = zeros(size(D));
for i = 1:length(S(1:end-1))
    E(i, :) = S(i).*D(i, :);
end

f = f(1:end-1);
theta = theta*180/pi;