function [out, info] = wsa_puvcoeffs(P, U, V, fs, un, z_p, z_v, h, varargin)
%wsa_puvcoeffs - coeficientes de la serie de Fourier a partir de datos PUV.
%
%   Esta función estima los primeros cuatro coeficientes de la serie de
%   Fourier (a1, b1, a2, b2) del espectro direccional del oleaje a partir
%   de mediciones PUV (presión y velocidades orbitales horizontales).
%
%   Las mediciones deben realizarse en cotas conocidas respecto al nivel
%   medio del mar, definidas mediante z_p (presión) y z_v (velocidades),
%   para aplicar la corrección hidrodinámica basada en teoría lineal de
%   ondas en profundidad finita.
%
%   La estimación de densidades espectrales se realiza mediante el método
%   de Welch-Barlett y los coeficientes se calculan siguiendo la formulación
%   clásica de (Longuet-Higgins et al., 1963).
%
%
%   Sintaxis:
%       out = wsa_puvcoeffs(P, U, V, fs, un, z_p, z_v, h)
%           estima los coeficientes direccionales a1, b1, a2 y b2.
%
%       [out, info] = wsa_puvcoeffs(P, U, V, fs, un, z_p, z_v, h)
%           devuelve adicionalmente una estructura info con los parámetros
%           internos utilizados en el cálculo.
%
%
%   Argumentos de entrada (requeridos):
%       P       - Señal de presión.
%                   Vector columna o fila.
%
%       U       - Velocidad orbital horizontal en dirección X.
%                   Vector del mismo tamaño que P.
%
%       V       - Velocidad orbital horizontal en dirección Y.
%                   Vector del mismo tamaño que P.
%
%       fs      - Frecuencia de muestreo.
%                   Escalar positivo [Hz].
%
%       un      - Unidad de la señal de presión.
%                   "dBa"  |  "m"
%
%       z_p     - Cota de medición de presión respecto al nivel medio.
%                   Escalar [m].
%                   Convención: negativo bajo el nivel medio.
%                   Debe cumplir: -h < z_p < 0.
%
%       z_v     - Cota de medición de velocidades respecto al nivel medio.
%                   Escalar [m].
%                   Convención: negativo bajo el nivel medio.
%                   Debe cumplir: -h < z_v < 0.
%
%       h       - Profundidad total del sitio.
%                   Escalar positivo [m].
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'g'         - Aceleración de la gravedad.
%                       Escalar [m/s^2].
%                       Por defecto: 9.81
%
%       'rho'       - Densidad del agua.
%                       Escalar [kg/m^3].
%                       Por defecto: 1025
%
%       'DoF'       - Grados de libertad del estimador de Welch.
%                       Entero positivo.
%                       Por defecto: 16
%
%       'pc'        - Print console. Muestra ajustes automáticos.
%                       true | false
%                       Por defecto: false
%
%       'Kp_min'    - Valor mínimo permitido para el factor de corrección
%                     dinámica de presión.
%                       Escalar positivo.
%                       Por defecto: 0.2
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       f           - Frecuencias físicas [Hz] (solo positivas)
%       W           - Frecuencias angulares digitales [rad/muestra]
%       a1          - Primer coeficiente de Fourier
%       b1          - Segundo coeficiente de Fourier
%       a2          - Tercer coeficiente de Fourier
%       b2          - Cuarto coeficiente de Fourier
%       k           - Número de onda asociado [rad/m]
%       Kp          - Factor de corrección dinámica de presión
%       Kc          - Factor de corrección dinámica de velocidad
%
%   info        - Estructura con información auxiliar del cálculo:
%                   info_Spp, info_Suu, info_Svv,
%                   info_Spu, info_Spv, info_Suv
%
%
%   Notas:
%   • Se elimina la componente hidrostática y la tendencia lineal antes
%     del análisis espectral.
%
%   • La corrección hidrodinámica se realiza mediante:
%
%         Kp = cosh(k(z_p + h)) / cosh(kh)
%         Kc = ω cosh(k(z_v + h)) / sinh(kh)
%
%     donde k satisface la relación de dispersión:
%
%         ω² = g k tanh(kh)
%
%   • Solo se reportan frecuencias positivas debido a la simetría del
%     espectro de Fourier.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 20/02/2026
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
addRequired(p, 'fs');
addRequired(p, 'un');
addRequired(p, 'z_p');
addRequired(p, 'z_v');
addRequired(p, 'h');

addParameter(p, 'g', g_default);
addParameter(p, 'rho',    rho_default);
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);
addParameter(p, 'Kp_min',    Kp_min_default);

parse(p, P, U, V, fs, un, z_p, z_v, h, varargin{:});

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

%% Componentes reales de las densidades espectrales cruzadas
%Partes real y de interés de las densidades espectrales cruzadas
%   Forma: Sxy = Cxy + i*Qxy
Cpp = real(Spp);
Cuu = real(Suu);
Cvv = real(Svv);
% Cpu = real(Spu);
% Cpv = real(Spv);
% Cuv = real(Suv);

Cpu = abs(Spu);
Cpv = abs(Spv);
Cuv = abs(Suv);

%% Coeficientes de corrección dinámica Kp y Kc

% Estimación teórica del número de onda
f = fs*W/(2*pi);
k = wsa_k(f, h, g);

Kp = cosh(k.*(z_p+h))./cosh(k.*h);
Kp(Kp < Kp_min) = Kp_min;         %Aplicar umbral de Kp.

Kp_v = (cosh(k.*(z_v+h))./cosh(k.*h));
Kp_v(abs(Kp_v) < Kp_min) = Kp_min;         %Aplicar umbral de Kc.

%% Coeficiente de conversión de velocidad a pendientes

omega = (2*pi*f);
alpha = omega./g;

%% Cálculo de los coeficientes
%   Se calculan los primeros 4 coeficientes de la serie de Fourier de la
%   señal del oleaje de acuerdo con (Longuet-Higgins et al., 1963) en su
%   artículo "Observations of the Directional Spectrum of Sea Waves Using
%   the Motions of a Floating Buoy".

Cpp = Cpp./(Kp.^2);
Cuu = Cuu./(Kp_v.^2);
Cvv = Cvv./(Kp_v.^2);
Cpu = Cpu./(Kp_v.*Kp);
Cpv = Cpv./(Kp_v.*Kp);
Cuv = Cuv./(Kp_v.^2);

k_exp = sqrt((Cuu+Cvv)./Cpp);


%Cálculo de coeficientes
% a1 = Cpu./(sqrt(Cpp.*(Cuu+Cvv)));
% b1 = Cpv./(sqrt(Cpp.*(Cuu+Cvv)));
% a2 = (Cuu-Cvv)./(Cuu+Cvv);
% b2 = 2*Cuv./(Cuu+Cvv);

a1 = (1./k_exp).*(Cpu./Cpp);
b1 = (1./k_exp).*(Cpv./Cpp);
a2 = (1./(k_exp.^2)).*((Cuu-Cvv)./Cpp);
b2 = (1./(k_exp.^2)).*(2*Cuv./Cpp);

%Convertir dirección del oleaje a "desde"
dir = pi;
a1_temp = a1*cos(dir) + b1*sin(dir);
b1_temp = -a1*sin(dir) + b1*cos(dir);
a2_temp = a2*cos(2*dir) + b2*sin(2*dir);
b2_temp = -a2*sin(2*dir) + b2*cos(2*dir);

a1 = a1_temp;
b1 = b1_temp;
a2 = a2_temp;
b2 = b2_temp;

%% Exportar resultados

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
out.Kc = Kp_v(W>0);

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