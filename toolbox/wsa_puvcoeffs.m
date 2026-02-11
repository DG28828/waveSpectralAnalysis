function [out, info] = wsa_puvcoeffs(P, U, V, un, fs, hm, h, varargin)
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
%       p - secuencia de presión 
%           vector
%       U - secuencia de velocidades orbitales en X
%           vector
%       V - secuencia de velocidades orbitales en Y
%           vector
%       un - unidad de los datos de entrada
%           string
%       fs - frecuencia de muestreo (Hz)
%           entero
%       hm - altura del equipo de medición respecto al fondo marino [m].
%           entero (positivo)
%       h - profundidad del fondo marino [m].
%           entero (positivo)
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
rho_default = 1025; %kg/m^3
DoF_default = 16;
pc_default = 0;
Kp_min_default = 0.2;

%Input parser
p = inputParser;

addRequired(p, 'P');
addRequired(p, 'U');
addRequired(p, 'V');
addRequired(p, 'un');
addRequired(p, 'fs');
addRequired(p, 'hm');
addRequired(p, 'h');

addParameter(p, 'g', g_default);
addParameter(p, 'rho',    rho_default);
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);
addParameter(p, 'Kp_min',    Kp_min_default);

parse(p, P, U, V, un, fs, hm, h, varargin{:});

%Resultados
g    = p.Results.g;
rho     = p.Results.rho;
DoF    = p.Results.DoF;
pc     = p.Results.pc;
Kp_min = p.Results.Kp_min;

%% Verificaciones iniciales


%% Conversión de unidades
%Si las unidades son dBa, se convierte a metros de columna de agua 
switch lower(string(un))
    case "dba"
        P = 10000*P; %1dBa = 10kPa (Primero se pasa a unidades SI)
        P = P./(rho*g); 
    case "m"
    otherwise
        error('Debe especificar alguna de las siguientes unidades: "dBa", "m"')
end

%% Eliminar presión hidrostática y eliminar tendencias
%   Se elimina la presión hidrostática para que la energía resultante
%   corresponda únicamente a la presión dinámica. Para esto se resta el
%   nivel medio de la señal de presión y se eliminan tendencias o señales
%   de muy baja frecuencia.
P = detrend(P-mean(P));
U = detrend(U-mean(U));
V = detrend(V-mean(V));

%% Densidades espectrales cruzadas

%Parámetros para las densidades espectrales cruzadas
% Por defecto: DoF = 16 ;
ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(P)/(K+1)));

%Densidades espectrales cruzadas
[out_Spp, info_Spp] = wsa_psdwb(P, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suu, info_Suu] = wsa_psdwb(U, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Svv, info_Svv] = wsa_psdwb(V, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spu, info_Spu] = wsa_psdwb(P, ventana,'Y',U, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spv, info_Spv] = wsa_psdwb(P, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suv, info_Suv] = wsa_psdwb(U, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
Spp = out_Spp.I; W = out_Spp.W;
Suu = out_Suu.I;
Svv = out_Svv.I;
Spu = out_Spu.I;
Spv = out_Spv.I;
Suv = out_Suv.I;

%% Coeficientes de corrección dinámica Kp y Kc

f = fs*W/(2*pi);
k = wsa_k(f, h, g);

Kp = cosh(k.*hm)./cosh(k.*h);
Kp(Kp < Kp_min) = Kp_min;         %Aplicar umbral de Kp.

Kc = (2*pi*f).*(cosh(k.*hm)./sinh(k.*h));
Kc(abs(Kc) < eps) = eps;         %Aplicar umbral de Kc.

%% Cálculo de los coeficientes
%   Se calculan los primeros 4 coeficientes de la serie de Fourier de la
%   señal del oleaje de acuerdo con (Longuet-Higgins et al., 1963) en su
%   artículo "Observations of the Directional Spectrum of Sea Waves Using
%   the Motions of a Floating Buoy".

%Partes real y de interés de las densidades espectrales cruzadas
%   Forma: Sxy = Cxy + i*Qxy
Cpu = real(Spu);
Cpv = real(Spv);
Cuv = real(Suv);

%Cálculo de coeficientes
%   Se suma "eps" a cada denominador, esto para evitar posibles problemas
%   de división por 0 y así no obtener NaNs o Infs.
a1 = (Kp./Kc).*Cpu./Spp;
b1 = (Kp./Kc).*Cpv./Spp;
a2 = ((Kp./Kc).^2).*(Suu-Svv)./Spp;
b2 = 2*((Kp./Kc).^2).*Cuv./Spp;

% Limitar coeficientes solo a frecuencias con energía
energy_threshold = 0.01 * max(Spp);
valid = Spp > energy_threshold;

a1(~valid) = 0;
b1(~valid) = 0;
a2(~valid) = 0;
b2(~valid) = 0;

%Exportar solo los coeficientes correspondientes a frecuencias positivas
% Solo en frecuencias positivas hay información relevante, la parte
% negativa es una reflexión respecto al eje y.

%Struct para resultados
out = struct;
out.W = W(W>0);             %Solo frecuencias positivas
out.f = f(W>0);
out.a1 = a1(W>0);
out.b1 = b1(W>0);
out.a2 = a2(W>0);
out.b2 = b2(W>0);
out.k = k(W>0);
out.Kp = Kp(W>0);
out.Kc = Kc(W>0);

% Otras salidas que podrían ser de interés
out.cross_spectra.W = W;
out.cross_spectra.Spp = Spp;
out.cross_spectra.Suu = Suu;
out.cross_spectra.Svv = Svv;
out.cross_spectra.Spu = Spu;
out.cross_spectra.Spv = Spv;
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