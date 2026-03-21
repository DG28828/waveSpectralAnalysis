function out_struct = wsa_spectral_parameters(arg1, arg2)
%wsa_spectral_parameters - calcula parámetros espectrales de oleaje
%
%   Sintaxis:
%       out = wsa_spectral_parameters(f, S)
%       out = wsa_spectral_parameters(spec)
%
%   Entradas:
%       f    : vector de frecuencias [Hz]
%       S    : vector de densidad espectral [m^2/Hz]
%
%       spec : struct con campos:
%              spec.f
%              spec.S
%
%   Salida:
%       out_struct con momentos y parámetros espectrales:
%           m0, m1, m2
%           eta_rms
%           Hm0
%           Tm02
%           fp, Tp
%           v
%           Qp

%% Manejo de entradas

narginchk(1, 2);

if nargin == 1
    %Caso en que el input es un struct (con campos f y S)
    in_struct = arg1;

    if ~isstruct(in_struct)
        error('Se especificó una sola entrada, esta debe ser un struct con campos f y S.')
    end

    if ~isfield(in_struct, 'f') || isempty(in_struct.f)
        error('El struct de entrada debe contener el campo f.')
    end

    if ~isfield(in_struct, 'S') || isempty(in_struct.S)
        error('El struct de entrada debe contener el campo S.')
    end

    f = in_struct.f;
    S = in_struct.S;
else
    %Caso en que el insput son 2 entradas: f y S
    f = arg1;
    S = arg2;
end

%% Verificaciones iniciales

if isempty(f)
    error('El vector de frecuencias f no puede estar vacío.')
end

if isempty(S)
    error('El vector espectral S no puede estar vacío.')
end

if ~isnumeric(f) || ~isnumeric(S)
    error('f y S deben ser arreglos numéricos.')
end

%Convertir a vector columna
f = f(:);
S = S(:);

if numel(f) ~= numel(S)
    error('Los vectores f y S deben tener la misma cantidad de elementos.')
end

if any(diff(f) <= 0)
    error('El vector de frecuencias f debe ser estrictamente creciente.')
end

if any(isnan(f)) || any(isnan(S))
    error('Los vectores f y S no deben contener NaN.')
end

%% Calculos

% Momentos
orders = [0, 1, 2];
in_struct = struct('S', S, 'f', f, 'n', orders);
moments_struct = wsa_moments(in_struct);

m0 = moments_struct.m(moments_struct.n == 0);
m1 = moments_struct.m(moments_struct.n == 1);
m2 = moments_struct.m(moments_struct.n == 2);

% Parametros
eta_rms = sqrt(m0);                                                         %Valor cuadratico medio de la superficie libre
Hrms = sqrt(8*m0);                                                        %Altura de ola cuadrática media
Hm0 = 4.004*eta_rms;                                                        %Altura de ola de momento de orden cero
Tm01 = m0/m1;                                                               %Periodo medio
Tm02 = sqrt(m0/m2);                                                         %Periodo medio

[~, idx_peak] = max(S);
fp = f(idx_peak);
if fp > 0
    Tp = 1/fp;                                                              % Período pico
else
    Tp = NaN;
end                                                                         

aux = (m0*m2)/(m1^2) - 1;
aux = max(aux, 0);                                                          % evita negativos pequeños por redondeo
v = sqrt(aux);                                                              %Parámetro de ancho espectral de Longuet-Higgins
Qp = 2*(trapz(f, f.*(S.^2)))/(m0.^2);                           %Agudeza de pico de Goda

%% Resultados

out_struct.m0 = m0;
out_struct.m1 = m1;
out_struct.m2 = m2;
out_struct.eta_rms = eta_rms;
out_struct.Hrms = Hrms; %Nuevo
out_struct.Hm0 = Hm0;
out_struct.Tm01 = Tm01; %Nuevo
out_struct.Tm02 = Tm02;
out_struct.Tp = Tp;
out_struct.fp = fp;
out_struct.v = v;
out_struct.Qp = Qp;
out_struct.used_spectra = struct('f', f, 'S', S);


end