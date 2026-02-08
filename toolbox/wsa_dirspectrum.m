function [out, info] = wsa_dirspectrum(eta, u, v, fs, varargin)
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
%       out - Salidas numéricas | struct
%           E - Valores de energía ([unidades de eta]^2/Hz/°)
%               vector
%           f - frecuencias físicas (Hz)
%               vector
%           theta - Angulos (°)
%               vector
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
[out_spectrum, info_spectrum] = wsa_spectrum(eta, fs, 'DoF', DoF, 'pc', pc);
S = out_spectrum.S;
f = out_spectrum.f;

%Coeficientes de la serie de Fourier
[out_puvcoeffs, info_puvcoeffs] = wsa_puvcoeffs(eta, u, v,'DoF', DoF, 'pc', pc);
d1 = out_puvcoeffs.a1;
d2 = out_puvcoeffs.b1;
d3 = out_puvcoeffs.a2;
d4 = out_puvcoeffs.b2;

%Función de distribución direccional
Ntheta = 180;
[out_dirmem, info_dirmem] = wsa_dirmem(d1, d2, d3, d4, Ntheta);
D = out_dirmem.D;
theta = out_dirmem.theta;

theta = theta*180/pi;   %Se convierte theta de [rad] a [°]
D = D*(pi/180);         %Se convierte D de [eta^2 / Hz / rad] a [eta^2 / Hz / °]

% Espectro direccional
E = zeros(size(D));
for i = 1:length(S(1:end-1))
    E(i, :) = S(i).*D(i, :);
end

%Vector de frecuencias
f = f(1:end-1);

%Verificación energética (área bajo la curva del espectro direccional)
S_i = zeros(size(E, 1), 1);
for k = 1:size(E, 1)
    S_i(k) = trapz(theta, E(k, :));
end
m0 = trapz(f, S_i);

%Struct para resultados
out = struct;
out.f = f;
out.theta = theta;
out.E = E;

% Otras salidas que podrían ser de interés
out.S = out_spectrum.S(1:end-1);
out.D = out_dirmem.D;
out.mem = out_dirmem.mem_params;
out.mem.f = f;
out.coeffs = out_puvcoeffs;
out.coeffs.cross_spectra = out_puvcoeffs.cross_spectra;

% Información
info = struct;
info.m0 = m0;
info.info_spectrum = info_spectrum;
info.info_puvcoeffs = info_puvcoeffs;
info.info_dirmem = info_dirmem;

end