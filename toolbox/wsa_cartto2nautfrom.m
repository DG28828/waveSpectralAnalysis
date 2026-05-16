function out = wsa_cartto2nautfrom(in)
%wsa_cartto2nautfrom - convierte direcciones convención cartesiana-hacia a náutica-desde
%
%   Esta función convierte direcciones y distribuciones direccionales
%   expresadas en convención cartesiana-hacia a convención náutica-desde.
%
%   La conversión aplicada corresponde a:
%
%       theta_naut = mod(270 - theta_cart, 360)
%
%   donde:
%
%       • Convención cartesiana-hacia:
%           - ángulos medidos desde el eje X positivo
%           - sentido antihorario
%           - dirección "hacia" donde viaja el oleaje
%
%       • Convención náutica-desde:
%           - ángulos medidos desde el norte
%           - sentido horario
%           - dirección "desde" donde proviene el oleaje
%
%
%   Por defecto, las siguientes funciones del toolbox brindan los 
%   resultados con angulos medidos en la convención cartesiana-hacia:
%       - wsa_dirspectrum
%       - wsa_directional_parameters
%
%   La función detecta automáticamente el tipo de struct que se esta
%   pasando.
%
%
%   Sintaxis:
%       out = wsa_cartto2nautfrom(in)
%
%
%   Argumentos de entrada:
%       in      - Struct de entrada.
%                   Puede corresponder a:
%                   • Struct de salida de wsa_dirspectrum
%                   • Struct de salida de wsa_directional_parameters
%                   • Struct interno de bandas generado por wsa_directional_parameters
%
%
%   Argumentos de salida:
%       out     - Struct con direcciones convertidas a convención
%                 náutica-desde.
%
%
%   Campos convertidos:
%
%   • Struct tipo wsa_dirspectrum:
%       Fourier.theta
%       MEM.theta
%       Fourier.E
%       Fourier.D
%       MEM.E
%       MEM.D
%
%       Las matrices son reordenadas para mantener la coherencia angular tras la conversión.
%
%   • Struct tipo wsa_directional_parameters:
%       DirTp
%       MeanDir
%       f_mean_dir
%       dir_mean_f
%
%       Además, la conversión se aplica sobre: out.bands.<nombre_banda>
%
%
%   Notas:
%   • La función no modifica el struct original; devuelve una copia
%     convertida.
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 13/05/2026
% Fecha de modificación: 15/05/2026
% -------------------------------------------------------------------------

%% Verificaciones iniciales

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