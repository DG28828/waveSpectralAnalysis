function [E, f, theta, info] = wsa_dirspectrum(eta, u, v, fs, varargin)
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
%       info - Información del cálculo
%           struct
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 04/02/2026
% Fecha de modificación: 04/02/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
DoF_default = 16;
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'eta');
addRequired(p, 'u');
addRequired(p, 'v');
addRequired(p, 'fs');

addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, eta, u, v, fs, varargin{:});

%Resultados
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%% Cálculo del espectro direccional
%   Esta función llama a las siguientes funciones:
%       - wsa_spectrum: calcula el espectro frecuencial S(f) a partir de eta
%       - wsa_puvcoeffs: calcula los coeficientes de la serie de Fourier a1,
%                       a2, b1, b2 a partir de eta, u y v.
%       - wsa_dirmem: estima la distribución direccional D(f, theta) a partir
%                       de los coeficientes de la serie de Fourier.
%
%       Posteriormente, calcula E(f, theta) = S(f)*D(f, theta).

%Espectro frecuencial
[S, f, info_spectrum] = wsa_spectrum(eta, fs, 'DoF', DoF, 'pc', pc);

%Coeficientes de la serie de Fourier
[coeffs, ~, info_puvcoeffs] = wsa_puvcoeffs(eta, u, v,'DoF', DoF, 'pc', pc);

%Función de distribución direccional
d1 = coeffs.a1;
d2 = coeffs.a2;
d3 = coeffs.b1;
d4 = coeffs.b2;
Ntheta = 360;
[D, theta] = wsa_dirmem(d1, d2, d3, d4, Ntheta);

theta = theta*180/pi;   %Se convierte theta de [rad] a [°]
D = D*(pi/180);         %Se convierte D de [eta^2 / Hz / rad] a [eta^2 / Hz / °]

% Espectro direccional
E = zeros(size(D));
for i = 1:length(S(1:end-1))
    E(i, :) = S(i).*D(i, :);
end

f = f(1:end-1);



% Información
info = struct;
info.info_spectrum = info_spectrum;
info.info_puvcoeffs = info_puvcoeffs;

end