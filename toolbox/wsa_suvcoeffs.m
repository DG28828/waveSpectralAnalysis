function [out, info] = wsa_suvcoeffs(S, U, V, fs, z, h, varargin)
%wsa_puvcoeffs - coeficientes de la serie de Fourier a partir de datos boya Heave-Pitch-Roll.
%
%   Esta función estima los primeros 4 coeficientes de la serie de Fourier
%   a1, a2, b1, b2 a partir de datos derivados de mediciones HPR (Heave-Pitch-Roll). 
%
%   Sintaxis:
%
%
%   Argumentos de entrada:
%       S - secuencia de superficie libre AST
%           vector
%       U - secuencia de velocidades X (a una profunidad z)
%           vector
%       V - secuencia de velocidades Y (a una profunidad z)
%           vector
%
%   Argumentos de salida:
%       out - Salidas numéricas | struct
%           a1 - primer coeficiente de la serie de Fourier
%               vector
%           a2 - segundo coeficiente de la serie de Fourier
%               vector
%           b1 - tercero coeficiente de la serie de Fourier
%               vector
%           b2 - cuarto coeficiente de la serie de Fourier
%               vector
%           W - Frecuencias angulares digitales (rad/muestra)
%               vector
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
g_default = 9.81;   %m's^2
DoF_default = 16;
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'S');
addRequired(p, 'U');
addRequired(p, 'V');
addRequired(p, 'fs');
addRequired(p, 'z');
addRequired(p, 'h');

addParameter(p, 'g', g_default);
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, S, U, V, fs, z, h, varargin{:});

%Resultados
g    = p.Results.g;
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%% Eliminar presión hidrostática y eliminar tendencias
%   Se elimina la presión hidrostática para que la energía resultante
%   corresponda únicamente a la presión dinámica. Para esto se resta el
%   nivel medio de la señal de presión y se eliminan tendencias o señales
%   de muy baja frecuencia.
S = detrend(S-mean(S));
U = detrend(U-mean(U));
V = detrend(V-mean(V));

%% Densidades espectrales cruzadas

%Parámetros para las densidades espectrales cruzadas
% Por defecto: DoF = 16 ;
ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(S)/(K+1)));

%Densidades espectrales cruzadas
[out_Spp, info_Spp] = wsa_psdwb(S, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suu, info_Suu] = wsa_psdwb(U, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Svv, info_Svv] = wsa_psdwb(V, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spu, info_Spu] = wsa_psdwb(S, ventana,'Y',U, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spv, info_Spv] = wsa_psdwb(S, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suv, info_Suv] = wsa_psdwb(U, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
Sss = out_Spp.I; W = out_Spp.W;
Suu = out_Suu.I;
Svv = out_Svv.I;
Ssu = out_Spu.I;
Ssv = out_Spv.I;
Suv = out_Suv.I;

%% Coeficientes de corrección dinámica Kp y Kc

f = fs*W/(2*pi);
k = wsa_k(f, h, g);

Kc = (2*pi*f).*(cosh(k.*(z+h))./sinh(k.*h));
Kc(abs(Kc) < 0.1) = 0.1;         %Aplicar umbral de Kc.
figure; plot(f, Kc);

%% Cálculo de los coeficientes
%   Se calculan los primeros 4 coeficientes de la serie de Fourier de la
%   señal del oleaje de acuerdo con (Longuet-Higgins et al., 1963) en su
%   artículo "Observations of the Directional Spectrum of Sea Waves Using
%   the Motions of a Floating Buoy".

%Partes real y de interés de las densidades espectrales cruzadas
%   Forma: Sxy = Cxy + i*Qxy
Css = real(Sss);
Cuu = real(Suu);
Cvv = real(Svv);
Csu = real(Ssu);
Csv = real(Ssv);
Cuv = real(Suv);


Cuu = Cuu./(Kc.^2);
Cvv = Cvv./(Kc.^2);
Csu = Csu./Kc;
Csv = Csv./Kc;
Cuv = Cuv./(Kc.^2);


%Cálculo de coeficientes
a1 = Csu./(sqrt(Css.*(Cuu+Cvv)));
b1 = Csv./(sqrt(Css.*(Cuu+Cvv)));
a2 = (Cuu-Cvv)./(Cuu+Cvv);
b2 = 2*Cuv./(Cuu+Cvv);


%Exportar solo los coeficientes correspondientes a frecuencias positivas
% Solo en frecuencias positivas hay información relevante, la parte
% negativa es una reflexión respecto al eje y.

%Struct para resultados
out = struct;
out.W = W(W>0);             %Solo frecuencias positivas
out.a1 = a1(W>0);
out.b1 = b1(W>0);
out.a2 = a2(W>0);
out.b2 = b2(W>0);

% Otras salidas que podrían ser de interés
out.cross_spectra.W = W;
out.cross_spectra.Spp = Sss;
out.cross_spectra.Suu = Suu;
out.cross_spectra.Svv = Svv;
out.cross_spectra.Spu = Ssu;
out.cross_spectra.Spv = Ssv;
out.cross_spectra.Suv = Suv;

% Información de cálculos
info = struct;
info.info_Spp = info_Spp;
info.info_Suu = info_Suu;
info.info_Svv = info_Svv;
info.info_Spu = info_Spu;
info.info_Spv = info_Spv;
info.info_Suv = info_Suv;

end