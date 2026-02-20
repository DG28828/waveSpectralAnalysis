function [out, info] = wsa_hprcoeffs(eta, d_eta_x, d_eta_y, varargin)
%wsa_hprcoeffs - coeficientes de la serie de Fourier a partir de datos HPR.
%
%   Esta función estima los primeros cuatro coeficientes de la serie de
%   Fourier (a1, b1, a2, b2) del espectro direccional del oleaje a partir
%   de mediciones HPR (heave, pitch y roll) típicas de boyas direccionales.
%
%   Se asume que:
%       eta      corresponde a la elevación superficial (heave),
%       d_eta_x  corresponde a la pendiente superficial en dirección X (pitch),
%       d_eta_y  corresponde a la pendiente superficial en dirección Y (roll).
%
%   La estimación de densidades espectrales se realiza mediante el método
%   de Welch-Barlett y los coeficientes se calculan siguiendo la formulación
%   clásica de (Longuet-Higgins et al., 1963).
%
%
%   Sintaxis:
%       out = wsa_hprcoeffs(eta, d_eta_x, d_eta_y)
%           estima los coeficientes direccionales a1, b1, a2 y b2.
%
%       [out, info] = wsa_hprcoeffs(eta, d_eta_x, d_eta_y)
%           devuelve adicionalmente una estructura info con los parámetros
%           internos utilizados en el cálculo.
%
%
%   Argumentos de entrada (requeridos):
%       eta         - Elevación superficial (heave).
%                       Vector columna o fila.
%
%       d_eta_x     - Pendiente superficial en dirección X (pitch).
%                       Vector del mismo tamaño que eta.
%
%       d_eta_y     - Pendiente superficial en dirección Y (roll).
%                       Vector del mismo tamaño que eta.
%
%
%   Parámetros Nombre-Valor (opcionales):
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
%                   info_Spp, info_Suu, info_Svv,
%                   info_Spu, info_Spv, info_Suv
%
%
%   Notas:
%   • Se asume que las señales han sido previamente calibradas y
%     transformadas a elevación y pendientes superficiales.
%
%   • Los coeficientes se obtienen a partir de las partes reales e
%     imaginarias de las densidades espectrales cruzadas:
%
%         a1 = Q12 / sqrt(C11 (C22 + C33))
%         b1 = Q13 / sqrt(C11 (C22 + C33))
%         a2 = (C22 - C33) / (C22 + C33)
%         b2 = 2 C23 / (C22 + C33)
%
%     donde Cij y Qij corresponden a las partes real e imaginaria de
%     las densidades espectrales cruzadas.
%
%   • Solo se reportan frecuencias positivas debido a la simetría del
%     espectro de Fourier.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 06/02/2026
% Fecha de modificación: 20/02/2026
% -------------------------------------------------------------------------


%% Manejo de entradas

%Valores por defecto
DoF_default = 16;
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'eta');
addRequired(p, 'd_eta_x');
addRequired(p, 'd_eta_y');

addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, eta, d_eta_x, d_eta_y, varargin{:});

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
[out_Spp, info_Spp] = wsa_psdwb(eta, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suu, info_Suu] = wsa_psdwb(d_eta_x, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Svv, info_Svv] = wsa_psdwb(d_eta_y, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spu, info_Spu] = wsa_psdwb(eta, ventana,'Y',d_eta_x, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Spv, info_Spv] = wsa_psdwb(eta, ventana,'Y',d_eta_y, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_Suv, info_Suv] = wsa_psdwb(d_eta_x, ventana,'Y',d_eta_y, 'K', K, 'Nfft', Nfft, 'pc', pc);
Spp = out_Spp.I; W = out_Spp.W;
Suu = out_Suu.I;
Svv = out_Svv.I;
Spu = out_Spu.I;
Spv = out_Spv.I;
Suv = out_Suv.I;

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
a1 = Q12./(sqrt(C11.*(C22+C33)));
b1 = Q13./(sqrt(C11.*(C22+C33)));
a2 = (C22-C33)./((C22+C33));
b2 = 2*C23./((C22+C33));

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