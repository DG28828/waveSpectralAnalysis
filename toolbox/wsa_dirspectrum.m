function [out, info] = wsa_dirspectrum(Z, X, Y, fs, method, varargin)
%wsa_dirspectrum - espectro de energía direccional.
%
%   Esta función estima el espectro de energía direccional a partir de 
%   mediciones en tres direcciones ortogonales capaces de proporcionar 
%   información direccional. 
%
%   La distribución direccional se estima empleando el método de máxima
%   entropía de Lygre & Krogstad (1986) (referirse a la función WSA_DIRMEM).
%   Los coeficientes de la serie de Fourier implicados en el cálculo se 
%   estiman dependiendo del tipo de mediciones realizadas. Las densidades 
%   espectrales y cruzadas se estiman empleando el método de Welch-Barlett.
%
%
%   Sintaxis:
%       out = wsa_dirspectrum(Z, X, Y, fs, method) estima el espectro de
%           energía direccional empleando el método especificado.
%
%       [out, info] = wsa_dirspectrum(Z, X, Y, fs, method) devuelve
%           adicionalmente una estructura info con información del cálculo.
%
%
%   Argumentos de entrada (requeridos):
%       Z       - Señal vertical.
%                   Vector.
%
%       X       - Señal en dirección X.
%                   Vector.
%
%       Y       - Señal en dirección Y.
%                   Vector.
%
%       fs      - Frecuencia de muestreo.
%                   Escalar positivo (Hz).
%
%       method  - Método de estimación direccional.
%                   "PUV" | "SUV" | "HPR"
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'DoF'   - Grados de libertad del espectro.
%                   Entero par, mayor o igual a 2.
%                   Por defecto: DoF = 16.
%
%       'pc'    - Print console.
%                   true | false
%                   Por defecto: false
%
%       (Requeridos cuando method = "PUV")
%
%       'un'    - Unidad de presión.
%                   "dBa" | "m"
%
%       'h'     - Profundidad del fondo marino.
%                   Escalar positivo (m).
%
%       'z_p'   - Profundidad del sensor de presión respecto al nivel medio.
%                   Escalar negativo (m).
%
%       'z_v'   - Profundidad del sensor de velocidad respecto al nivel medio.
%                   Escalar negativo (m).
%
%       (Opcionales físicos adicionales para "PUV")
%
%       'g'     - Aceleración gravitacional.
%                   Por defecto: g = 9.81 m/s^2.
%
%       'rho'   - Densidad del agua.
%                   Por defecto: rho = 1025 kg/m^3.
%
%       'Kp_min' - Valor mínimo permitido para el factor de corrección
%                   hidrodinámica.
%                   Por defecto: Kp_min = 0.2.
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       E           - Espectro direccional
%                   [unidad^2 / Hz / °]
%       f           - Frecuencias físicas (Hz)
%       theta       - Direcciones (°)
%
%       (Adicionalmente se incluyen:)
%       S           - Espectro frecuencial
%       D           - Distribución direccional
%       mem         - Parámetros del método MEM
%       coeffs      - Coeficientes de Fourier y espectros cruzados
%
%   info        - Estructura con información del cálculo:
%                   m0,
%                   info_spectrum,
%                   info_puvcoeffs,
%                   info_dirmem
%
%
%   Notas:
%   • El método "PUV" emplea presión y velocidades horizontales medidas
%     bajo la superficie.
%   • El método "SUV" emplea elevación superficial y velocidades.
%   • El método "HPR" emplea mediciones tipo heave-pitch-roll.
%   • La distribución direccional D(f,θ) se estima mediante el método de
%     máxima entropía (MEM).
%   • El espectro direccional final se calcula como:
%
%         E(f,θ) = S(f) · D(f,θ)
%
%   • Se verifica la consistencia energética integrando E(f,θ) en θ y f
%     para obtener el momento espectral m0.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 04/02/2026
% Fecha de modificación: 20/02/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
DoF_default = 16;
pc_default = 0;

% Valores por defecto de parámetros opcionales requeridos en caso de method = 'PUV'
un_default = [];
h_default = [];
z_default = [];

% Valores por defecto de parámetros opcionales, no requeridos en caso de method = 'PUV'
g_default = 9.81;   %m's^2
rho_default = 1025; %kg/m^3
Kp_min_default = 0.2;

%Input parser
p = inputParser;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'Z');
addRequired(p, 'X');
addRequired(p, 'Y');
addRequired(p, 'fs');
addRequired(p, 'method');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%

% Parámetros opcionales
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

%Parámetros opcionales requeridos en caso de method = 'PUV'
addParameter(p, 'un', un_default)
addParameter(p, 'h', h_default)
addParameter(p, 'z_p', z_default)
addParameter(p, 'z_v', z_default)

% Parámetros opcionales, no requeridos en caso de method = 'PUV'
addParameter(p, 'g', g_default);
addParameter(p, 'rho',    rho_default);
addParameter(p, 'Kp_min',    Kp_min_default);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, Z, X, Y, fs, method, varargin{:});

%%%%%%%    Resultados     %%%%%%%%

%Resultados
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%Parámetros opcionales requeridos en caso de method = 'PUV'
un      = p.Results.un;
h       = p.Results.h;
z_p       = p.Results.z_p;
z_v       = p.Results.z_v;

%Resultados de parámetros opcionales, no requeridos en caso de method = 'PUV'
g    = p.Results.g;
rho     = p.Results.rho;
Kp_min = p.Results.Kp_min;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales

% Agregar verificacion para z, debe ser negativo y mayor a -h.

if lower(string(method)) == "puv"
    if isempty(un) || isempty(z_p) || isempty(z_v) || isempty(h)
        error('El método PUV requiere de los siguientes parámetros:\n\t un: unidad de presión  "dba" o "m" \n\t\t string | char \n\t hm: altura del equipo de medición respecto al fondo marino [m]. \n\t\t entero (positivo)\n\t h: profundidad del fondo marino [m]. \n\t\t entero (positivo)\n %s', '');
    end

    if ~ischar(un) && ~isstring(un)
        error('El parámetro "un" debe ser string o char ("dba" o "m").')
    end

    if ~ismember(lower(string(un)), ["dba","m"])
        error('El parámetro "un" debe ser "dba" o "m".')
    end

    if ~isscalar(h) || h <= 0
        error('El parámetro "h" debe ser un escalar positivo.')
    end

    if ~isscalar(z_p) || z_p >= 0 || z_p <= -h
        error('z_p debe ser escalar y cumplir -h < z_p < 0');
    end
    
    if ~isscalar(z_v) || z_v >= 0 || z_v <= -h
        error('z_v debe ser escalar y cumplir -h < z_v < 0');
    end
end

%% Cálculo del espectro direccional
%   Esta función llama a las siguientes funciones:
%       - wsa_pspectrum: calcula el espectro frecuencial S(f) a partir de p
%       - wsa_spectrum: calcula el espectro frecuencial S(f) a partir de eta
%       - wsa_puvcoeffs: calcula los coeficientes de la serie de Fourier a1,
%                       a2, b1, b2 a partir de p, u y v (medidas en el fondo).
%       - wsa_hprcoeffs: calcula los coeficientes de la serie de Fourier a1,
%                       a2, b1, b2 a partir de heave-pitch-roll (boya en superficie).
%       - wsa_dirmem: estima la distribución direccional D(f, theta) a partir
%                       de los coeficientes de la serie de Fourier.
%
%       Posteriormente, calcula E(f, theta) = S(f)*D(f, theta).

% Cálculo de S(f) y coeficientes de Fourier según método
switch lower(string(method))
    case "puv"
        P = Z;
        U = X;
        V = Y;
        [out_spectrum, info_spectrum] = wsa_pspectrum(P, fs, un, z_p, h, 'DoF', DoF, 'pc', pc, 'g', g, 'rho', rho, 'Kp_min', Kp_min);
        [out_coeffs, info_coeffs] = wsa_puvcoeffs(P, U, V, fs, un, z_p, z_v, h, 'DoF', DoF, 'pc', pc, 'g', g, 'rho', rho, 'Kp_min', Kp_min);
    case "suv"
        S = Z; S = detrend(S-mean(S));
        U = X;
        V = Y;
        [out_spectrum, info_spectrum] = wsa_spectrum(S, fs, 'DoF', DoF, 'pc', pc);
        [out_coeffs, info_coeffs] = wsa_suvcoeffs(S, U, V, fs, z_v, h, 'DoF', DoF, 'pc', pc);
    case "hpr"
        eta = Z;
        d_eta_x = X;
        d_eta_y = Y;
        [out_spectrum, info_spectrum] = wsa_spectrum(eta, fs, 'DoF', DoF, 'pc', pc);
        [out_coeffs, info_coeffs] = wsa_hprcoeffs(eta, d_eta_x, d_eta_y,'DoF', DoF, 'pc', pc);
    otherwise
        error('Debe especificar alguno de los siguientes métodos: "PUV", "SUV", "HPR"')
end

%Espectro frecuencial
S = out_spectrum.S;
f = out_spectrum.f;

%Coeficientes de la serie de Fourier
d1 = out_coeffs.a1;
d2 = out_coeffs.b1;
d3 = out_coeffs.a2;
d4 = out_coeffs.b2;

%Función de distribución direccional
Ntheta = 180;
[out_dirmem, info_dirmem] = wsa_dirmem(d1, d2, d3, d4, Ntheta);
D = out_dirmem.D;
theta = out_dirmem.theta;

theta = theta*180/pi;   %Se convierte theta de [rad] a [°]
D = D*(pi/180);         %Se convierte D de [eta^2 / Hz / rad] a [eta^2 / Hz / °]

% Espectro direccional (Evaluar hacer E = S(1:end-1) .* D; )
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
out.coeffs = out_coeffs;
out.coeffs.cross_spectra = out_coeffs.cross_spectra;

% Información
info = struct;
info.m0 = m0;
info.info_spectrum = info_spectrum;
info.info_puvcoeffs = info_coeffs;
info.info_dirmem = info_dirmem;

end