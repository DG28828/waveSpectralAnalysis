function out = wsa_band_parameters(f, S)
%wsa_compute_band_parameters - Calcula los parámetros espectrales para la
%banda de frecuencia (entrada corresponde a la banda de frecuencia)

% Inicializar salida por si la banda no tiene suficientes datos
out = empty_output();

if isempty(f) || isempty(S)
    return
end

if numel(f) < 2
    % El vector de frecuencias debe tener al menos 2 puntos para poder
    % integrar 
    return
end

% Si los valores de S son cero
if all(S == 0)
    out.m0 = 0;
    out.m1 = 0;
    out.m2 = 0;
    out.m4 = 0;
    out.eta_rms = 0;
    out.Hrms = 0;
    out.Hm0 = 0;
    out.Tm01 = NaN;
    out.Tm02 = NaN;
    out.Tp = NaN;
    out.fp = NaN;
    out.v = NaN;
    out.Qp = NaN;
    return
end

% Momentos
orders = [0, 1, 2, 4];
in_struct = struct('S', S, 'f', f, 'n', orders);
moments_struct = wsa_moments(in_struct);

m0 = moments_struct.m(moments_struct.n == 0);
m1 = moments_struct.m(moments_struct.n == 1);
m2 = moments_struct.m(moments_struct.n == 2);
m4 = moments_struct.m(moments_struct.n == 4);

% Parámetros
eta_rms = sqrt(m0);                 %Valor cuadratico medio de la superficie libre
Hrms = sqrt(8*m0);                  %Altura de ola cuadrática media
Hm0 = 4.004*eta_rms;                %Altura de ola de momento de orden cero

if m1 > 0                           %Periodo medio (con momento de orden 1)
    Tm01 = m0/m1;
else
    Tm01 = NaN;
end

if m2 > 0                           %Periodo medio (con momento de orden 2)
    Tm02 = sqrt(m0/m2);
else
    Tm02 = NaN;
end

[Smax, idx_peak] = max(S);          % Período pico y frecuencia pico
if isempty(idx_peak) || Smax <= 0
    fp = NaN;
    Tp = NaN;
else
    fp = f(idx_peak);
    if fp > 0
        Tp = 1/fp;
    else
        Tp = NaN;
    end
end

if m1 > 0 && m0 > 0 && m2 > 0       %Parámetro de ancho espectral de Longuet-Higgins
    aux = (m0*m2)/(m1^2) - 1;
    aux = max(aux, 0);
    v = sqrt(aux);
else
    v = NaN;
end

if m0 > 0                           %Agudeza de pico de Goda
    Qp = 2 * trapz(f, f .* (S.^2)) / (m0^2);
else
    Qp = NaN;
end

% Salida
out.m0 = m0;
out.m1 = m1;
out.m2 = m2;
out.m4 = m4;
out.eta_rms = eta_rms;
out.Hrms = Hrms;
out.Hm0 = Hm0;
out.Tm01 = Tm01;
out.Tm02 = Tm02;
out.Tp = Tp;
out.fp = fp;
out.v = v;
out.Qp = Qp;
end

function out = empty_output()
out = struct( ...
    'm0', NaN, ...
    'm1', NaN, ...
    'm2', NaN, ...
    'm4', NaN, ...
    'eta_rms', NaN, ...
    'Hrms', NaN, ...
    'Hm0', NaN, ...
    'Tm01', NaN, ...
    'Tm02', NaN, ...
    'Tp', NaN, ...
    'fp', NaN, ...
    'v', NaN, ...
    'Qp', NaN);
end