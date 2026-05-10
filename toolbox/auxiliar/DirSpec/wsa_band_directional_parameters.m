function out = wsa_band_directional_parameters(f, S, a1, b1, a2, b2)
%wsa_band_directional_parameters - Calcula los parámetros direccionales para la
%banda de frecuencia (entrada corresponde a la banda de frecuencia)

% Inicializar salida por si la banda no tiene suficientes datos
out = wsa_empty_dir_output();

if isempty(f) || isempty(S) || isempty(a1) || isempty(b1)
    return
end

if numel(f) < 2
    % El vector de frecuencias debe tener al menos 2 puntos para poder
    % integrar 
    return
end

% Si los valores de S son cero
if all(S == 0)
    out.fp = NaN;
    out.Tp = NaN;
    out.DirTp = NaN;
    out.SprTp = NaN;
    out.MeanDir = NaN;
    out.MeanSpread = NaN;
    out.m0 = 0;
    out.a1_wa = NaN;
    out.b1_wa = NaN;
    out.R1_wa = NaN;

    if ~isempty(a2) && ~isempty(b2)
        out.dir2_mean_f = mod(rad2deg(atan2(b2, a2))/2, 360);
        R2 = sqrt(a2.^2 + b2.^2);
        R2 = min(max(R2, 0), 1);
        out.spread2_f = rad2deg(sqrt(0.5 * (1 - R2)));
    end    

    return
end

% Momento de orden cero
m0 = trapz(f, S);

% Dirección media por frecuencia
f_mean_dir = mod(rad2deg(atan2(b1, a1)), 360);

%Spreading por frecuencia
R1 = sqrt(a1.^2 + b1.^2);
R1 = min(max(R1, 0), 1);
f_dir_spr = rad2deg(sqrt(2 * (1 - R1)));

% Frecuencia pico de la banda
[Smax, idx_peak] = max(S);
if isempty(idx_peak) || Smax <= 0
    fp = NaN;
    Tp = NaN;
    DirTp = NaN;
    SprTp = NaN;
else
    fp = f(idx_peak);

    if fp > 0
        Tp = 1 / fp;
    else
        Tp = NaN;
    end

    DirTp = f_mean_dir(idx_peak);
    SprTp = f_dir_spr(idx_peak);
end

% Parámetros globales ponderados energéticamente
if m0 > 0
    a1_wa = trapz(f, S .* a1) / m0;
    b1_wa = trapz(f, S .* b1) / m0;

    MeanDir = mod(rad2deg(atan2(b1_wa, a1_wa)), 360);

    R1_wa = sqrt(a1_wa.^2 + b1_wa.^2);
    R1_wa = min(max(R1_wa, 0), 1);
    MeanSpread = rad2deg(sqrt(2 * (1 - R1_wa)));
else
    a1_wa = NaN;
    b1_wa = NaN;
    MeanDir = NaN;
    R1_wa = NaN;
    MeanSpread = NaN;
end

% Guardar resultados principales
out.fp = fp;
out.Tp = Tp;
out.DirTp = DirTp;
out.SprTp = SprTp;
out.MeanDir = MeanDir;
out.MeanSpread = MeanSpread;
out.f_mean_dir = f_mean_dir;
out.f_dir_spr = f_dir_spr;
out.m0 = m0;
out.a1_wa = a1_wa;
out.b1_wa = b1_wa;
out.R1_wa = R1_wa;



end

%% Funciones auxiliares

function out = wsa_empty_dir_output()
out = struct( ...
    'fp', NaN, ...
    'Tp', NaN, ...
    'DirTp', NaN, ...
    'SprTp', NaN, ...
    'MeanDir', NaN, ...
    'MeanSpread', NaN, ...
    'f_mean_dir', [], ...
    'f_dir_spr', [], ...
    'm0', NaN, ...
    'a1_bar', NaN, ...
    'b1_bar', NaN, ...
    'R1_bar', NaN ...
    );



end