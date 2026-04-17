function [out, info] = wsa_dir_coeffs(X1, X2, X3, varargin)
%wsa_dircoeffs - coeficientes direccionales a1, b1, a2, b2.
%
%   Esta función estima los primeros cuatro coeficientes de la serie de
%   Fourier de la función de distribución direccional del oleaje a partir 
%   de tres tipos de medición:
%
%       1) PUV : presión + velocidades orbitales U,V
%       2) SUV : elevación superficial + velocidades orbitales U,V
%       3) HPR : heave + pitch + roll (o elevación + pendientes)
%
%   Sintaxis:
%       out = wsa_dircoeffs(X1, X2, X3, 'InputType', 'HPR')
%       out = wsa_dircoeffs(S, U, V, 'InputType', 'SUV', 'fs', fs, 'z_v', z_v, 'h', h)
%       out = wsa_dircoeffs(P, U, V, 'InputType', 'PUV', 'fs', fs, 'un', 'dBa', 'z_p', z_p, 'z_v', z_v, 'h', h)
%
%   Argumentos de entrada (requeridos):
%       X1      - Señal del oleaje con información en el eje Z vertical.
%                   Vector columna o fila.
%
%       X2       - Señal del oleaje con información en el eje X horizontal.
%                   Vector columna o fila.
%
%       X3       - Señal del oleaje con información en el eje Y horizontal.
%                   Vector columna o fila.
%
%   Parámetros Nombre-Valor Requeridos para PUV:
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
%   Parámetros Nombre-Valor Opcionales para PUV:
%       'g'         - Aceleración de la gravedad.
%                       Escalar [m/s^2].
%                       Por defecto: 9.81
%
%       'rho'       - Densidad del agua.
%                       Escalar [kg/m^3].
%                       Por defecto: 1025
%
%       'Kp_min'    - Valor mínimo permitido para el factor de corrección
%                     dinámica de presión.
%                       Escalar positivo.
%                       Por defecto: 0.2
%
%   Parámetros Nombre-Valor Requeridos para SUV:
%
%       fs      - Frecuencia de muestreo.
%                   Escalar positivo [Hz].
%
%       z_v     - Cota de medición de las velocidades respecto al nivel medio.
%                   Escalar [m].
%                   Convención: negativo bajo el nivel medio.
%                   Debe cumplir: -h < z <= 0.
%
%       h       - Profundidad total del sitio.
%                   Escalar positivo [m].
%
%   Parámetros Nombre-Valor Opcionales para SUV:
%
%       'g'     - Aceleración de la gravedad.
%                   Escalar [m/s^2].
%                   Por defecto: 9.81
%
%   Parámetros Nombre-Valor Opcionales:
%
%       ventana - Tipo de ventana a emplear.
%                   "rectangular" | "hann" | "hamming"
%
%       'DoF'   - Grados de libertad del estimador de Welch.
%                   Entero positivo.
%                   Por defecto: 16
%
%       'pc'    - Print console. Muestra ajustes automáticos.
%                   true | false
%                   Por defecto: false
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 17/04/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
InputType_default = "HPR";
ventana_default = "hann";
DoF_default = 16;
pc_default = 0;
corr_flag_default = false;

g_default = 9.81;   %m's^2
rho_default = 1025; %kg/m^3
Kp_min_default = 0.2;

%Input parser
p = inputParser;

addRequired(p, 'X1');
addRequired(p, 'X2');
addRequired(p, 'X3');

addParameter(p, 'InputType', InputType_default);
addParameter(p, 'ventana', ventana_default);
addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);
addParameter(p, 'corr_flag', corr_flag_default);

addParameter(p, 'fs', []);
addParameter(p, 'un', []);
addParameter(p, 'z_p', []);
addParameter(p, 'z_v', []);
addParameter(p, 'h', []);
addParameter(p, 'g', g_default);
addParameter(p, 'rho',    rho_default);
addParameter(p, 'Kp_min',    Kp_min_default);


parse(p, X1, X2, X3, varargin{:});

%Resultados
InputType = upper(string(p.Results.InputType));
ventana   = p.Results.ventana;
fs        = p.Results.fs;
DoF       = p.Results.DoF;
pc        = p.Results.pc;
corr_flag = p.Results.corr_flag;

un        = p.Results.un;
z_p       = p.Results.z_p;
z_v       = p.Results.z_v;
h         = p.Results.h;
g         = p.Results.g;
rho       = p.Results.rho;
Kp_min    = p.Results.Kp_min;

%% Verificaciones iniciales

%Verificar que entradas sean vectores. Convertir todo a vector columna
if ~isvector(X1) || ~isvector(X2) || ~isvector(X3)
    error('X1, X2 y X3 deben ser vectores.');
end
X1 = X1(:);
X2 = X2(:);
X3 = X3(:);

if ~(numel(X1)==numel(X2) && numel(X1)==numel(X3))
    error('X1, X2 y X3 deben tener el mismo número de elementos.');
end

%Verificar que DoF indicado es entero, par, mayor o igual a 2
if DoF ~= DoF_default
    if DoF < 2 || mod(DoF, 1) ~= 0 || mod(DoF, 2) ~= 0
        error('DoF debe ser entero, par, mayor o igual a 2')
    end
end

%Verificar que InputType es alguna de las opciones válidas
if InputType ~= "PUV" && InputType ~= "SUV" && InputType ~= "HPR"
    error('InputType debe ser "PUV", "SUV" o "HPR".');
end

if ~isempty(fs)
    if ~isscalar(fs) || fs <= 0
        error('Debe especificar fs como escalar positivo.');
    end
end


% Validaciones específicas por InputType
switch InputType
    case "PUV"
        if isempty(fs) || isempty(un) || isempty(z_p) || isempty(z_v) || isempty(h)
            error('Para InputType="PUV" debe especificar: fs, un, z_p, z_v, h.');
        end
        if ~(h > 0)
            error('h debe ser positivo.');
        end
        if ~(z_p < 0 && z_p > -h)
            error('z_p debe cumplir -h < z_p < 0.');
        end
        if ~(z_v <= 0 && z_v > -h)
            error('z_v debe cumplir -h < z_v <= 0.');
        end

    case "SUV"
        if isempty(fs) || isempty(z_v) || isempty(h)
            error('Para InputType="SUV" debe especificar: fs, z_v, h.');
        end
        if ~(h > 0)
            error('h debe ser positivo.');
        end
        if ~(z_v <= 0 && z_v > -h)
            error('z_v debe cumplir -h < z_v <= 0.');
        end

    case "HPR"
        % no requiere parámetros adicionales
end


%% Preprocesamiento
switch InputType
    case "PUV"
        switch lower(string(un))
            case "dba"
                %Si las unidades son dBa, se convierte a metros de columna de agua 
                X1 = 10000*X1;       % dBa -> Pa   1dBa = 10kPa (Primero se pasa a unidades SI)
                X1 = X1./(rho*g);    % Pa -> m de columna de agua
            case "m"
                % Si ya esta en metros, no se hace nada
            otherwise
                error('La unidad "un" debe ser "dBa" o "m".');
        end
        X1 = detrend(X1 - mean(X1));
        X2 = detrend(X2 - mean(X2));
        X3 = detrend(X3 - mean(X3));

    case {"SUV", "HPR"}
        X1 = detrend(X1 - mean(X1));
        X2 = detrend(X2 - mean(X2));
        X3 = detrend(X3 - mean(X3));
end

%% Densidades espectrales cruzadas
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(X1)/(K+1)));

[out_S11, info_S11] = wsa_psdwb(X1, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_S22, info_S22] = wsa_psdwb(X2, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_S33, info_S33] = wsa_psdwb(X3, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);

[out_S12, info_S12] = wsa_psdwb(X1, ventana, 'Y', X2, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_S13, info_S13] = wsa_psdwb(X1, ventana, 'Y', X3, 'K', K, 'Nfft', Nfft, 'pc', pc);
[out_S23, info_S23] = wsa_psdwb(X2, ventana, 'Y', X3, 'K', K, 'Nfft', Nfft, 'pc', pc);

W   = out_S11.W;
S11 = out_S11.I;
S22 = out_S22.I;
S33 = out_S33.I;
S12 = out_S12.I;
S13 = out_S13.I;
S23 = out_S23.I;

f = fs*W/(2*pi);
f_abs = abs(f);

%% Cálculo de coeficientes según modo
switch InputType
    case "HPR"
        % Según tu implementación actual:
        % a1,b1 usan partes imaginarias de S12,S13
        % a2,b2 usan partes reales de S23,S22,S33
        C11 = real(S11);
        C22 = real(S22);
        C33 = real(S33);
        C23 = real(S23);
        Q12 = imag(S12);
        Q13 = imag(S13);

        a1 = Q12./sqrt(C11.*(C22 + C33));
        b1 = Q13./sqrt(C11.*(C22 + C33));
        a2 = (C22 - C33)./(C22 + C33);
        b2 = 2*C23./(C22 + C33);

        k = [];
        Kp = [];
        Kp = [];

    case "SUV"
        Css = real(S11);
        Cuu = real(S22);
        Cvv = real(S33);
        Csu = real(S12);
        Csv = real(S13);
        Cuv = real(S23);

        k = wsa_k(f_abs, h, g);

        Kp = cosh(k.*(z_v+h))./cosh(k.*h);
        Kp(abs(Kp) < Kp_min) = Kp_min;

        Cuu = Cuu./(Kp.^2);
        Cvv = Cvv./(Kp.^2);
        Csu = Csu./Kp;
        Csv = Csv./Kp;
        Cuv = Cuv./(Kp.^2);

        Kexp = sqrt((Cuu + Cvv)./Css);

        a1 = (1./Kexp).*(Csu./Css);
        b1 = (1./Kexp).*(Csv./Css);
        a2 = (1./(Kexp.^2)).*((Cuu - Cvv)./Css);
        b2 = (1./(Kexp.^2)).*(2*Cuv./Css);

        %Kp = [];
        
    case "PUV"
        Cpp = real(S11);
        Cuu = real(S22);
        Cvv = real(S33);
        Cpu = real(S12);
        Cpv = real(S13);
        Cuv = real(S23);

        k = wsa_k(f, h, g);

        Kp = cosh(k.*(z_p+h))./cosh(k.*h);
        Kp(Kp < Kp_min) = Kp_min;

        Kp = cosh(k.*(z_v+h))./cosh(k.*h);
        Kp(abs(Kp) < Kp_min) = Kp_min;

        Cpp = Cpp./(Kp.^2);
        Cuu = Cuu./(Kp.^2);
        Cvv = Cvv./(Kp.^2);
        Cpu = Cpu./(Kp.*Kp);
        Cpv = Cpv./(Kp.*Kp);
        Cuv = Cuv./(Kp.^2);

        k_exp = sqrt((Cuu + Cvv)./Cpp);

        a1 = (1./k_exp).*(Cpu./Cpp);
        b1 = (1./k_exp).*(Cpv./Cpp);
        a2 = (1./(k_exp.^2)).*((Cuu - Cvv)./Cpp);
        b2 = (1./(k_exp.^2)).*(2*Cuv./Cpp);
end

%% Exportar resultados
idx_pos = W > 0;

out = struct;
out.InputType = InputType;
out.W = W(idx_pos);
out.f = f(idx_pos);
out.a1 = a1(idx_pos);
out.b1 = b1(idx_pos);
out.a2 = a2(idx_pos);
out.b2 = b2(idx_pos);

if ~isempty(k)
    out.k = k(idx_pos);
end
if ~isempty(Kp)
    out.Kp = Kp(idx_pos);
end
% if ~isempty(Kc)
%     out.Kc = Kc(idx_pos);
% end

out.cross_spectra.W = W;
out.cross_spectra.S11 = S11;
out.cross_spectra.S22 = S22;
out.cross_spectra.S33 = S33;
out.cross_spectra.S12 = S12;
out.cross_spectra.S13 = S13;
out.cross_spectra.S23 = S23;
out.cross_spectra.S12_corr = S12;
out.cross_spectra.S13_corr = S13;
out.cross_spectra.S23_corr = S23;

info = struct;
info.info_S11 = info_S11;
info.info_S22 = info_S22;
info.info_S33 = info_S33;
info.info_S12 = info_S12;
info.info_S13 = info_S13;
info.info_S23 = info_S23;
%info.phase_correction = diag_corr;




end