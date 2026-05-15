function out = wsa_cartto2nautfrom(in)
%wsa_cartto2nautfrom Convierte convención cartesiana-hacia a náutica-desde
%
%   Por defecto, el toolbox brinda los resultados con angulos medidos en la
%   siguiente convención:
%       - Cartesiana: desde el eje X positivo en dirección de las manecillas del reloj
%       - Desde: dirección "desde" donde viene el oleaje.
%
%   Este script se puede utilizar para convertir los resultados de los
%   siguientes structs de datos:
%       - struct de wsa_dirspectrum
%       - struct de wsa_directional_parameters
%
%   La función detecta automáticamente el tipo de struct que se esta
%   pasando.

out = in;

if ~isstruct(in)
    error('Input debe ser un struct.');
end

%% Caso 1: struct tipo wsa_dirspectrum
if isfield(in, 'Fourier') && isfield(in, 'MEM')

    methods = {'Fourier','MEM'};

    for k = 1:numel(methods)

        method = methods{k};

        theta = out.(method).theta;
        E     = out.(method).E;
        D     = out.(method).D;

        % Conversión
        theta_new = mod(270 - theta, 360);

        % Reordenar
        [theta_new, idx] = sort(theta_new);
        E_new = E(:, idx);
        D_new = D(:, idx);

        % Guardar
        out.(method).theta = theta_new;
        out.(method).E = E_new;
        out.(method).D = D_new;

    end

    return
end

%% Caso 2: struct tipo wsa_directional_parameters

% Detectar si es estructura de parámetros
if isfield(in, 'DirTp') || isfield(in, 'MeanDir')

    out = convert_param_struct(out);
    return
end

%% Caso 3: struct de banda (interno)
if isfield(in, 'bands')
    out = convert_param_struct(out);
    return
end

warning('No se reconoció el tipo de struct. No se realizó conversión.');

end


%% Funcions auxiliares
function s = convert_param_struct(s)

    % Campos principales
    if isfield(s, 'DirTp')
        s.DirTp = mod(270 - s.DirTp, 360);
    end

    if isfield(s, 'MeanDir')
        s.MeanDir = mod(270 - s.MeanDir, 360);
    end

    if isfield(s, 'f_mean_dir') && ~isempty(s.f_mean_dir)
        s.f_mean_dir = mod(270 - s.f_mean_dir, 360);
    end

    if isfield(s, 'dir_mean_f') && ~isempty(s.dir_mean_f)
        s.dir_mean_f = mod(270 - s.dir_mean_f, 360);
    end

    % Caso bandas
    if isfield(s, 'bands')

        band_names = fieldnames(s.bands);

        for i = 1:numel(band_names)

            band = band_names{i};
            s.bands.(band) = convert_param_struct(s.bands.(band));

        end
    end

end