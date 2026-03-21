function out_struct = wsa_spectral_parameters(arg1, arg2, varargin)
%wsa_spectral_parameters - calcula parámetros espectrales de oleaje
%
%   Sintaxis:
%       out = wsa_spectral_parameters(f, S)
%       out = wsa_spectral_parameters(spec)
%       out = wsa_spectral_parameters(..., 'TotalBand', [fmin fmax])
%       out = wsa_spectral_parameters(..., 'Bands', bands_struct)
%       out = wsa_spectral_parameters(..., 'CustomBands', custom_struct)
%       out = wsa_spectral_parameters(..., 'IncludeDefaultBands', true/false)
%
%   Entradas:
%       f    : vector de frecuencias [Hz]
%       S    : vector de densidad espectral [m^2/Hz]
%
%       spec : struct con campos:
%              spec.f
%              spec.S
%
%   Parámetros nombre-valor:
%       'TotalBand'           : [fmin fmax] para limitar el cálculo principal
%                               (por defecto usa todo el espectro)
%       'Bands'               : struct con bandas por defecto redefinidas
%                               Ejemplo:
%                               struct('ig',[1/300 1/30], 'wind',[1/8 1/5])
%       'CustomBands'         : struct con bandas adicionales personalizadas
%                               Ejemplo:
%                               struct('sea',[0.10 0.20], 'lowfreq',[0.03 0.07])
%       'IncludeDefaultBands' : true/false, incluye o no las bandas por defecto
%
%   Salida:
%       out_struct con:
%           parámetros principales del espectro o banda TotalBand
%           out_struct.bands.<nombre_banda> con parámetros por banda
%           out_struct.band_definitions con límites usados

%% Manejo de entradas

narginchk(1, inf);

if isstruct(arg1)
    %Caso en que el input es un struct (con campos f y S)

    in_struct = arg1;

    if ~isfield(in_struct, 'f') || isempty(in_struct.f)
        error('El struct de entrada debe contener el campo f.')
    end

    if ~isfield(in_struct, 'S') || isempty(in_struct.S)
        error('El struct de entrada debe contener el campo S.')
    end

    f = in_struct.f;
    S = in_struct.S;

    if nargin >= 2
        name_value_args = [{arg2}, varargin];
    else
        name_value_args = {};
    end

else
    %Caso en que el insput son 2 entradas: f y S

    if nargin < 2
        error(['Si no se usa un struct de entrada, deben proporcionarse ', ...
               'ambos argumentos: f y S.'])
    end

    f = arg1;
    S = arg2;

    name_value_args = varargin;
end

% Valores por defecto
TotalBand_default = [];                             %Todo el espectro por defecto
Bands_default = struct();                           %Vacio por defecto
CustomBands_default = struct();                     %Vacio por defecto
IncludeDefaultBands_default = true;                 %Incluye las bandas por defecto por defecto

% Input Parser
p = inputParser;
p.FunctionName = 'wsa_spectral_parameters';

%Parametros opcionales
addParameter(p, 'TotalBand', TotalBand_default, @(x) isempty(x) || wsa_is_valid_band(x));
addParameter(p, 'Bands', Bands_default, @(x) isstruct(x));
addParameter(p, 'CustomBands', CustomBands_default, @(x) isstruct(x));
addParameter(p, 'IncludeDefaultBands', IncludeDefaultBands_default, @(x) islogical(x) && isscalar(x));

parse(p, name_value_args{:});
opts = p.Results;


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

if any(~isfinite(f)) || any(~isfinite(S))
    error('Los vectores f y S deben contener únicamente valores finitos.');
end

%% Definicion de bandas por defecto y struct final de bandas

%Bandas por defecto
default_bands = struct( ...
                        'ig', [1/300, 1/30], ...
                        'swell1', [1/30, 1/12.5], ...
                        'swell2', [1/12.5, 1/8], ...
                        'swell', [1/30, 1/8], ...
                        'wind', [1/8, 1/5] ...
                        );

%Guardar bandas por defecto
all_bands = struct();
if opts.IncludeDefaultBands
    all_bands = default_bands;
end

% Sobreescribir bandas por defecto si el usuario indicó limites distintos
if ~isempty(fieldnames(opts.Bands))
    user_bands = wsa_validate_band_struct(opts.Bands, 'Bands');             % Verifica que las bandas dadas por el usuario tengan el formato correcto,
                                                                            %   si no brinda error del tipo: 'El campo "banda" de "bands" debe ser un vector numérico [fmin fmax] finito y con fmin < fmax.
    %Guardar bandas dadas por el usuario en struct de bandas
    fn = fieldnames(user_bands);
    for k = 1:numel(fn)
        all_bands.(fn{k}) = user_bands.(fn{k});
    end
end

% Agregar bandas personalizadas adicionales
if ~isempty(fieldnames(opts.CustomBands))
    custom_bands = wsa_validate_band_struct(opts.CustomBands, 'CustomBands');   %Verificar que bandas tengan formato adecuado
    fn_custom = fieldnames(custom_bands);               
    fn_all = fieldnames(all_bands);

    repeated = intersect(fn_custom, fn_all);                                %Verificar si existen bandas brindadas por el usuario que son iguales a las bandas existentes por defecto
    if ~isempty(repeated)
        error(['Los nombres de CustomBands no deben repetir nombres ya existentes. ', ...
               'Nombre(s) repetido(s): %s'], strjoin(repeated, ', '));
    end
    
    %Guardar bandas adicionales en el struct de bandas
    for k = 1:numel(fn_custom)
        all_bands.(fn_custom{k}) = custom_bands.(fn_custom{k});
    end
end


%% Cálculo principal - Parámetros del espectro total

if isempty(opts.TotalBand)                                                  % Si no se especifican nuevos límites, usar completo
    f_total = f;
    S_total = S;
    total_limits = [f(1), f(end)];                                          
else                                                                        % Usar nuevos limites si son especificados
    total_limits = opts.TotalBand;
    [f_total, S_total] = wsa_extract_band(f, S, total_limits);
end

main = wsa_band_spectral_parameters(f_total, S_total);                               % Calcular parámetros totales
main.band_limits = total_limits;
main.used_spectra = struct('f', f_total, 'S', S_total);

out_struct = main;

%% Cálculo por bandas de frecuencia

out_struct.bands = struct();
band_names = fieldnames(all_bands);

%Calcular parámetros para cada banda
for k = 1:numel(band_names)
    band_name = band_names{k};
    band_limits = all_bands.(band_name);

    [f_band, S_band] = wsa_extract_band(f, S, band_limits);
    band_out = wsa_band_spectral_parameters(f_band, S_band);                         

    band_out.band_limits = band_limits;
    band_out.used_spectra = struct('f', f_band, 'S', S_band);

    valid_name = matlab.lang.makeValidName(band_name);
    out_struct.bands.(valid_name) = band_out;
end

%% Adicionales

out_struct.band_definitions = all_bands;
out_struct.total_band_definition = total_limits;
out_struct.source_spectra = struct('f', f, 'S', S); 


end