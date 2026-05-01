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

%% Estimación del espectro frecuencial

% Cálculo de S(f) y coeficientes de Fourier según método
switch lower(string(method))
    case "puv"
        P = Z;
        [out_spectrum, info_spectrum] = wsa_spectrum(P, fs, 'InputType', "pressure", 'DoF', DoF, 'pc', pc, 'un', un, 'z_p', z_p, 'h', h, 'g', g, 'rho', rho, 'Kp_min', Kp_min);
    case "suv"
        S = detrend(Z-mean(Z));
        [out_spectrum, info_spectrum] = wsa_spectrum(S, fs, 'DoF', DoF, 'pc', pc);
    case "hpr"
        eta = Z;
        [out_spectrum, info_spectrum] = wsa_spectrum(eta, fs, 'DoF', DoF, 'pc', pc);
    otherwise
        error('Debe especificar alguno de los siguientes métodos: "PUV", "SUV", "HPR"')
end

%Espectro frecuencial
S = out_spectrum.S;
f = out_spectrum.f;

%Espectro frecuencial (para frecuencias positivas)
Spos = S(2:end);
fpos = f(2:end);

%% Método: Serie de Fourier


% Cálculo de coeficientes de Fourier según método
switch lower(string(method))
    case "puv"
        P = Z;
        U = X;
        V = Y;
        [out_coeffs, info_coeffs] = wsa_dir_coeffs(P, U, V, 'InputType', 'PUV', 'fs', fs, 'un', un,'z_p', z_p, 'z_v', z_v, 'h', h, 'DoF', DoF, 'pc', pc, 'g', g, 'rho', rho, 'Kp_min', Kp_min);
    case "suv"
        S = Z;
        U = X;
        V = Y;
        [out_coeffs, info_coeffs] = wsa_dir_coeffs(S, U, V, 'InputType', 'SUV', 'fs', fs, 'z_v', z_v, 'h', h, 'DoF', DoF, 'pc', pc);
    case "hpr"
        eta = Z;
        d_eta_x = X;
        d_eta_y = Y;
        [out_coeffs, info_coeffs] = wsa_dir_coeffs(eta, d_eta_x, d_eta_y, 'InputType', 'HPR','DoF', DoF, 'pc', pc); 
    otherwise
        error('Debe especificar alguno de los siguientes métodos: "PUV", "SUV", "HPR"')
end

%Coeficientes de la serie de Fourier (definido solo para frecuencias positivas)
a1 = out_coeffs.a1;
b1 = out_coeffs.b1;
a2 = out_coeffs.a2;
b2 = out_coeffs.b2;


%Estimación de la función de distribución direccional
Ntheta = 180;
out_Fourier = wsa_dir_TFS(a1, b1, Ntheta, a2, b2);
%out_Fourier = wsa_dir_TFS(a1, b1, Ntheta);

theta = rad2deg(out_Fourier.theta);   %Se convierte theta de [rad] a [°]
D = out_Fourier.D*(pi/180);         %Se convierte D de [eta^2 / Hz / rad] a [eta^2 / Hz / °]

% Espectro direccional
E = Spos(:).*D;

%Verificación energética (área bajo la curva del espectro direccional)
S_i = trapz(theta, E, 2);
m0 = trapz(fpos, S_i);

% Struct con resultados
Fourier = struct;
Fourier.f = fpos;
Fourier.theta = theta;
Fourier.D = D;
Fourier.E = E;
Fourier.S = Spos;
Fourier.m0 = m0;
Fourier.coeffs = out_coeffs;

%% Método: Máxima Entropía Lygre & Krogstad (MEM I)

% Cálculo de coeficientes de Fourier según método
switch lower(string(method))
    case "puv"
        P = Z;
        U = X;
        V = Y;
        [corr_out_coeffs, info_coeffs] = wsa_dir_coeffs(P, U, V, 'InputType', 'PUV', 'fs', fs, 'un', un,'z_p', z_p, 'z_v', z_v, 'h', h, 'DoF', DoF, 'pc', pc, 'g', g, 'rho', rho, 'Kp_min', Kp_min, 'corr_flag', false);
    case "suv"
        S = Z; S = detrend(S-mean(S));
        U = X;
        V = Y;
        [corr_out_coeffs, info_coeffs] = wsa_dir_coeffs(S, U, V, 'InputType', 'SUV', 'fs', fs, 'z_v', z_v, 'h', h, 'DoF', DoF, 'pc', pc, 'corr_flag', false);
    case "hpr"
        eta = Z;
        d_eta_x = X;
        d_eta_y = Y;
        [corr_out_coeffs, info_coeffs] = wsa_dir_coeffs(eta, d_eta_x, d_eta_y, 'InputType', 'HPR','DoF', DoF, 'pc', pc);  %Se debe agregar correccion en caso de requerirse
    otherwise
        error('Debe especificar alguno de los siguientes métodos: "PUV", "SUV", "HPR"')
end

%Coeficientes con corrección de fase
a1_corr = corr_out_coeffs.a1;
b1_corr = corr_out_coeffs.b1;
a2_corr = corr_out_coeffs.a2;
b2_corr = corr_out_coeffs.b2;

%Función de distribución direccional (definido solo la frecuencias positivas)
Ntheta = 180;
[out_dirmem, info_dirmem] = wsa_dir_MEM1(a1_corr, b1_corr, a2_corr, b2_corr, Ntheta);
D = out_dirmem.D;
theta = out_dirmem.theta;

theta = rad2deg(theta);   %Se convierte theta de [rad] a [°]
D = D*(pi/180);         %Se convierte D de [eta^2 / Hz / rad] a [eta^2 / Hz / °]

% Espectro direccional
E = Spos(:).*D;

%Verificación energética (área bajo la curva del espectro direccional)
S_i = trapz(theta, E, 2);
m0 = trapz(fpos, S_i);

%Recálculo de los Coeficientes de la Serie de Fourier
theta_rad = deg2rad(theta);   % si theta está en grados
mem_a1 = trapz(theta, E.*cos(theta_rad), 2)./Spos(:);
mem_b1 = trapz(theta, E.*sin(theta_rad), 2)./Spos(:);
mem_a2 = trapz(theta, E.*cos(2*theta_rad), 2)./Spos(:);
mem_b2 = trapz(theta, E.*sin(2*theta_rad), 2)./Spos(:);

mem_coeffs = struct();
mem_coeffs.W = out_coeffs.W;
mem_coeffs.a1 = mem_a1;
mem_coeffs.b1 = mem_b1;
mem_coeffs.a2 = mem_a2;
mem_coeffs.b2 = mem_b2;

% Struct con resultados
MEM = struct;
MEM.f = fpos;
MEM.theta = theta;
MEM.D = D;
MEM.E = E;
MEM.S = Spos;
MEM.m0 = m0;
MEM.C1 = out_dirmem.mem_params.C1;
MEM.C2 = out_dirmem.mem_params.C2;
MEM.phi1 = out_dirmem.mem_params.phi1;
MEM.phi2 = out_dirmem.mem_params.phi2;
MEM.coeffs = corr_out_coeffs; %Coeficientes antes de MEM
MEM.coeffs_mem = mem_coeffs;  %Coeficientes después de MEM

%% Resultados
%Struct para resultados
out = struct;
out.Fourier = Fourier;
out.MEM = MEM;


% Información
info = struct;
info.m0 = m0;
info.info_spectrum = info_spectrum;
info.info_coeffs = info_coeffs;
info.info_dirmem = info_dirmem;

end