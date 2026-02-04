function [coeffs, W, info] = wsa_puvcoeffs(eta, u, v, varargin)
%wsa_puvcoeffs - coeficientes de la serie de Fourier a partir de datos PUV.
%
%   Esta función estima los primeros 4 coeficientes de la serie de Fourier
%   a1, a2, b1, b2 a partir de datos derivados de mediciones PUV (presión y
%   velocidades orbitales). Los datos de entrada deben estar ubicados en
%   superficie y adecuadamente corregidos hidrodinámicamente.
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
%
%   Argumentos de salida:
%       coeffs - coeficientes de la serie de Fourier (a1, a2, b1, b2)
%           struct
%       info - Información de parámetros finales del cálculo
%           struct
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 03/02/2026
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

addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, eta, u, v, varargin{:});

%Resultados
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%% Cálculo de los coeficientes
%   Se calculan los primeros 4 coeficientes de la serie de Fourier de la
%   señal del oleaje de acuerdo con (Longuet-Higgins et al., 1963) en su
%   artículo "Observations of the Directional Spectrum of Sea Waves Using
%   the Motions of a Floating Buoy".

%Parámetros para las densidades espectrales cruzadas
% Por defecto: DoF = 16 ;
ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(eta)/(K+1)));

%Densidades espectrales cruzadas
[Spp, W, info_Spp] = wsa_psdwb(eta, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[Suu, ~, info_Suu] = wsa_psdwb(u, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[Svv, ~, info_Svv] = wsa_psdwb(v, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[Spu, ~, info_Spu] = wsa_psdwb(eta, ventana,'Y',u, 'K', K, 'Nfft', Nfft, 'pc', pc);
[Spv, ~, info_Spv] = wsa_psdwb(eta, ventana,'Y',v, 'K', K, 'Nfft', Nfft, 'pc', pc);
[Suv, ~, info_Suv] = wsa_psdwb(u, ventana,'Y',v, 'K', K, 'Nfft', Nfft, 'pc', pc);

%Partes real y de interés de las densidades espectrales cruzadas
%   Forma: Sxy = Cxy + i*Qxy
C11 = real(Spp);
C22 = real(Suu);
C33 = real(Svv);
C23 = real(Suv);
Q12 = imag(Spu);
Q13 = imag(Spv);

%Cálculo de coeficientes
%   Se suma "eps" a cada denominador, esto para evitar posibles problemas
%   de división por 0 y así no obtener NaNs o Infs.
a1 = Q12./(sqrt(C11.*(C22+C33))+eps);
a2 = Q13./(sqrt(C11.*(C22+C33))+eps);
b1 = (C22-C33)./((C22+C33+eps));
b2 = 2*C23./((C22+C33+eps));

%Exportar solo los coeficientes correspondientes a frecuencias positivas
% Solo en frecuencias positivas hay información relevante, la parte
% negativa es una reflexión respecto al eje y.
coeffs = struct;
coeffs.a1 = a1(W>0);
coeffs.a2 = a2(W>0);
coeffs.b1 = b1(W>0);
coeffs.b2 = b2(W>0);
W = W(W>0);             %Solo frecuencias positivas

% Información de cálculos
info = struct;
info.info_Spp = info_Spp;
info.info_Suu = info_Suu;
info.info_Svv = info_Svv;
info.info_Spu = info_Spu;
info.info_Spv = info_Spv;
info.info_Suv = info_Suv;

end