function [out, info] = wsa_pspectrum(P, un, fs, hm, h, varargin)
%wsa_spectrum - espectro de energía a partir de registro de presión
%
%   Esta función estima el espectro de energía de una secuencia de 
%   datos de presión (X). El espectro calculado corresponde a la densidad 
%   espectral de potencia unilateral (frecuencias positivas). El espectro 
%   se calcula mediante el método de periodogramas medio, siguiendo la 
%   metodología de Welch-Barlett. El espectro resultante presenta corrección
%   hidrodinámica.
%
%   Sintaxis:
%
%
%   Argumentos de entrada:
%       P - secuencia de datos de presión [dBa] | [m]
%           vector
%       un - unidad de los datos de entrada
%           string
%       fs - frecuencia de muestreo (Hz)
%           entero
%       hm - altura del equipo de medición respecto al fondo marino [m].
%           entero (positivo)
%       h - profundidad del fondo marino [m].
%           entero (positivo)
%       DoF - grados de libertad (Degrees of Freedom) del espectro. Debe
%       ser entero, par, mayor o igual a 2.
%           entero | (opcional) Por defecto: DoF = 16
%       pc - Bandera para imprimir en consola (print consle): brinda
%       información acerca de modificaciones en valores de M, N, N0, K, Nfft
%           bool | (opcional) Por defecto: 0
%
%   Argumentos de salida:
%       out - Salidas numéricas | struct
%           S - estimador del espectro de energía unilateral m^2/Hz
%               vector
%           f - frecuencias físicas Hz
%               vector
%       info - Información de parámetros finales del cálculo
%           struct
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 30/01/2026
% Fecha de modificación: 07/02/2026
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
addRequired(p, 'un');
addRequired(p, 'fs');
addRequired(p, 'hm');
addRequired(p, 'h');

addParameter(p, 'g', g_default);
addParameter(p, 'rho',    rho_default);
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);
addParameter(p, 'Kp_min',    Kp_min_default);

parse(p, P, un, fs, hm, h, varargin{:});

%Resultados
g    = p.Results.g;
rho     = p.Results.rho;
DoF    = p.Results.DoF;
pc     = p.Results.pc;
Kp_min = p.Results.Kp_min;

%% Verificaciones iniciales

%Verificar P es vector columna
if size(P, 1) ~= length(P)
    P = P';
end

%Verificar que variable un es string o char *PENDIENTE
%

if DoF ~= DoF_default
    if DoF < 2 || mod(DoF, 1) ~= 0 || mod(DoF, 2) ~= 0
        error('DoF debe ser entero, par, mayor o igual a 2')
    end
end

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

%% Eliminar presión hidrostática
%   Se elimina la presión hidrostática para que la energía resultante
%   corresponda únicamente a la presión dinámica. Para esto se resta el
%   nivel medio de la señal de presión y se eliminan tendencias o señales
%   de muy baja frecuencia.
P = detrend(P-mean(P));

%% Calculo del espectro de energía
% Se calcula el espectro de energía unilateral a partir de la estimación de
% densidad de potencia mediante el método de Welch-Barlett. Los parámetros
% empleados son:
%   ventana: Von Hann
%   K: tal que cumpla con los DoF. Por defecto K = 8 (Recordar DoF = 2K)
%   N: Por defecto N = 2*M/(K+1) para N0 = N/2
%   N0: Por defecto N0 = N/2, para un porcentaje de traslape del 50 % que
%       disminuye la varainza a aproximadamente la mitad (mas traslape no dismiuye mas la varianza).
%   Nfft: la potencia de 2 mayor mas cercana a 4 veces N.

ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(P)/(K+1)));
[out_pswb, info] = wsa_psdwb(P, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
Ipp = out_pswb.I;
W = out_pswb.W;

%Convertir psd bilateral a espectro unilateral y convertir 
% Conversión:
%   PSD bilateral: [X^2 / rad/muestra]
%   PSD unilateral: [X^2 / rad/s] = [eta^2 / Hz]
Spp = Ipp(W>=0)/fs;   
Spp(2:end) = 2*Spp(2:end); %La componente DC (W=0) no se duplica
f = fs*W(W>=0)/(2*pi);

% *Esta conversión es la siguiente:
%       W:  frecuencia angular digital [rad/muestra]
%       fs: frecuencia de muestreo [muestra/s]
%       f:  frecuencia física [rad/s] = [rad/muestra]/[s/muestra]

%Validación energética:
%   Se verifica el cumplimiento de integral_0_inf(S(f)df) = varianza
m0 = trapz(f, Spp);       %El momento de primer orden es el área bajo la curva
varianza = var(P);     %Varianza de la señal de entrada
error_relativo = 100*abs(m0-varianza)/varianza;
if pc
    fprintf('Validación energética:\n\t m0 = %.4f (área bajo la curva) \n\t varianza señal = %.4f \n\t error relativo = %.2f %%\n', m0, varianza, error_relativo)
end

%% Corrección hidrodinámica
%   Se escalan los factores del espectro por el factor de corrección
%   hidrodinámica Kp.
%
%   Spp = Kp^2*S  -->  S = Spp/Kp^2  ecuación (7.34) (Ochi, 1998)
%   
%   Kp = rho*g*(cosh(z+h))/(cosh(kh))     ecuación (7.33) (Ochi, 1998)
%
%   Nota: Kp es dependiente de omega

% Calculo del número de onda k para cada frecuencia f, para esto se emplea
% un método númerico para resolver la ecuación de dispersión. Se emplea la
% función wsa_k que calcula k(f) mediante el método de NewtonRaphson.

k = wsa_k(f, h, g);

Kp = cosh(k.*hm)./cosh(k.*h);
Kp(Kp<Kp_min) = Kp_min;         %Aplicar umbral de Kp. 
S = Spp./(Kp.^2);


%% Guardado de resultados
%Struct para resultados
out = struct;
out.S = S;
out.f = f;
out.Spp = Spp;
out.Kp = Kp;
out.k = k;

%Agregar información adicional al struct de info
info.fs = fs;
info.varianza = varianza;  
info.m0 = m0;
info.error_relativo = error_relativo;

end