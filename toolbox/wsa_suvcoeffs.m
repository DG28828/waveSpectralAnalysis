function [out, info] = wsa_suvcoeffs(S, U, V, fs, z_v, h, varargin)
%wsa_suvcoeffs - coeficientes de la serie de Fourier a partir de datos SUV.
%
%   Esta función estima los primeros cuatro coeficientes de la serie de
%   Fourier (a1, b1, a2, b2) del espectro direccional del oleaje a partir
%   de mediciones SUV (elevación superficial y velocidades orbitales
%   horizontales).
%
%   Las velocidades deben corresponder a una cota conocida z_v respecto al
%   nivel medio del mar para aplicar la corrección hidrodinámica basada en
%   teoría lineal de ondas en profundidad finita.
%
%   La estimación de densidades espectrales se realiza mediante el método
%   de Welch-Barlett y los coeficientes se calculan siguiendo la formulación
%   clásica de (Longuet-Higgins et al., 1963).
%
%
%   Sintaxis:
%       out = wsa_suvcoeffs(S, U, V, fs, z_v, h)
%           estima los coeficientes direccionales a1, b1, a2 y b2.
%
%       [out, info] = wsa_suvcoeffs(S, U, V, fs, z_v, h)
%           devuelve adicionalmente una estructura info con los parámetros
%           internos utilizados en el cálculo.
%
%
%   Argumentos de entrada (requeridos):
%       S       - Elevación superficial (η).
%                   Vector columna o fila.
%
%       U       - Velocidad orbital horizontal en dirección X.
%                   Vector del mismo tamaño que S.
%
%       V       - Velocidad orbital horizontal en dirección Y.
%                   Vector del mismo tamaño que S.
%
%       fs      - Frecuencia de muestreo.
%                   Escalar positivo [Hz].
%
%       z_v     - Cota de medición de las velocidades respecto al nivel medio.
%                   Escalar [m].
%                   Convención: negativo bajo el nivel medio.
%                   Debe cumplir: -h < z < 0.
%
%       h       - Profundidad total del sitio.
%                   Escalar positivo [m].
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'g'     - Aceleración de la gravedad.
%                   Escalar [m/s^2].
%                   Por defecto: 9.81
%
%       'DoF'   - Grados de libertad del estimador de Welch.
%                   Entero positivo.
%                   Por defecto: 16
%
%       'pc'    - Print console. Muestra ajustes automáticos.
%                   true | false
%                   Por defecto: false
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       W           - Frecuencias angulares digitales [rad/muestra]
%       a1          - Primer coeficiente de Fourier
%       b1          - Segundo coeficiente de Fourier
%       a2          - Tercer coeficiente de Fourier
%       b2          - Cuarto coeficiente de Fourier
%
%   info        - Estructura con información auxiliar del cálculo:
%                   info_Sss, info_Suu, info_Svv,
%                   info_Ssu, info_Ssv, info_Suv
%
%
%   Notas:
%   • Se elimina la media y la tendencia lineal de las señales antes
%     del análisis espectral.
%
%   • La corrección hidrodinámica de velocidades se realiza mediante:
%
%         Kc = ω cosh(k(z + h)) / sinh(kh)
%
%     donde k satisface la relación de dispersión:
%
%         ω² = g k tanh(kh)
%
%   • No se aplica corrección dinámica a S, ya que corresponde a la
%     elevación superficial.
%
%   • Solo se reportan frecuencias positivas debido a la simetría del
%     espectro de Fourier.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 11/02/2026
% Fecha de modificación: 20/02/2026
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

parse(p, S, U, V, fs, z_v, h, varargin{:});

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
[out_Sss, info_Sss] = wsa_psdwb(S, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suu, info_Suu] = wsa_psdwb(U, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Svv, info_Svv] = wsa_psdwb(V, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Ssu, info_Ssu] = wsa_psdwb(S, ventana,'Y',U, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Ssv, info_Ssv] = wsa_psdwb(S, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suv, info_Suv] = wsa_psdwb(U, ventana,'Y',V, 'K', K, 'Nfft', Nfft, 'pc', pc);
Sss = out_Sss.I; W = out_Sss.W;
Suu = out_Suu.I;
Svv = out_Svv.I;
Ssu = out_Ssu.I;
Ssv = out_Ssv.I;
Suv = out_Suv.I;

%% Coeficientes de corrección dinámica Kp y Kc

f = fs*W/(2*pi);
k = wsa_k(f, h, g);

Kc = (2*pi*f).*(cosh(k.*(z_v+h))./sinh(k.*h));
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

%% Exportar resultados

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
out.cross_spectra.Sss = Sss;
out.cross_spectra.Suu = Suu;
out.cross_spectra.Svv = Svv;
out.cross_spectra.Ssu = Ssu;
out.cross_spectra.Ssv = Ssv;
out.cross_spectra.Suv = Suv;

% Información de cálculos
info = struct;
info.info_Sss = info_Sss;
info.info_Suu = info_Suu;
info.info_Svv = info_Svv;
info.info_Ssu = info_Ssu;
info.info_Ssv = info_Ssv;
info.info_Suv = info_Suv;

end