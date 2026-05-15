function out_struct = wsa_directional_parameters(arg1, varargin)
%wsa_directional_parameters - calcula parámetros direccionales de oleaje.
%
%   Esta función calcula parámetros direccionales a partir de los
%   coeficientes de Fourier de la distribución direccional:
%   a1(f), b1(f). Opcionalmente acepta también a2(f), b2(f).
%
%   Los parámetros se calculan tanto para el espectro completo, como para 
%   las bandas de frecuencia definidas por defecto. También permite el 
%   cálculo de bandas personalizadas.
%
%   Bandas por defecto:
%       ig     : [1/300, 1/30] Hz
%       swell1 : [1/30, 1/12.5] Hz
%       swell2 : [1/12.5, 1/8] Hz
%       swell  : [1/30, 1/8] Hz
%       wind   : [1/8, 1/2] Hz
%
%
%   Sintaxis:
%       out = wsa_directional_parameters(dirspec)
%       out = wsa_directional_parameters(f, S, a1, b1)
%       out = wsa_directional_parameters(..., 'a2', a2, 'b2', b2)
%       out = wsa_directional_parameters(..., 'TotalBand', [fmin fmax])
%       out = wsa_directional_parameters(..., 'Bands', bands_struct)
%       out = wsa_directional_parameters(..., 'CustomBands', custom_struct)
%       out = wsa_directional_parameters(..., 'IncludeDefaultBands', true/false)
%
%   Entradas:
%       dirspec : struct de salida de wsa_dirspectrum con campos:
%                 dirspec.f
%                 dirspec.S
%                 dirspec.coeffs.a1
%                 dirspec.coeffs.b1
%                 (opcional) dirspec.coeffs.a2
%                 (opcional) dirspec.coeffs.b2
%
%       f       : vector de frecuencias [Hz]
%       S       : espectro frecuencial [m^2/Hz]
%       a1, b1  : coeficientes de Fourier de primer orden
%
%   Parámetros nombre-valor:
%       'a2'                    : coeficiente a2(f) (opcional)
%       'b2'                    : coeficiente b2(f) (opcional)
%       'TotalBand'             : [fmin fmax] para limitar el cálculo principal
%       'Bands'                 : struct con bandas por defecto redefinidas
%       'CustomBands'           : struct con bandas adicionales personalizadas
%       'IncludeDefaultBands'   : true/false
%
%   Salida:
%       out_struct con:
%           fp
%           Tp
%           DirTp
%           SprTp
%           MeanDir
%           MeanSpread
%           f_mean_dir          (vector de direcciones medias para cada frecuencia)
%           f_dir_spr           (vector de spread direccional para cada frecuencia)
%           m0
%           band_limits
%           used_spectra
%           bands.<nombre_banda> (struct con parámetros)
%           band_definitions     (struct con definición de las bandas)
%           total_band_definition
%           source_spectra       (struct con el espectro y coeficientes de entrada)
%           
%           
%
%

%% Manejo de entradas

narginchk(1, inf);

if isstruct(arg1)
    % Caso en el que el input es un struct con los campos f, S, coeffs.a1 y coeffs.b1
    
    in_struct = arg1;

    if ~isfield(in_struct, 'f') || isempty(in_struct.f)
        error('El struct de entrada debe contener el campo f.')
    end

    if ~isfield(in_struct, 'S') || isempty(in_struct.S)
        error('El struct de entrada debe contener el campo S.')
    end

    if ~isfield(in_struct, 'coeffs') || isempty(in_struct.coeffs)
        error('El struct de entrada debe contener el campo coeffs.');
    end

    if ~isfield(in_struct.coeffs, 'a1') || isempty(in_struct.coeffs.a1)
        error('El struct de entrada debe contener el campo coeffs.a1.');
    end

    if ~isfield(in_struct.coeffs, 'b1') || isempty(in_struct.coeffs.b1)
        error('El struct de entrada debe contener el campo coeffs.b1.');
    end
    
    % Valores requeridos requeridos
    f  = in_struct.f;
    S  = in_struct.S;
    a1 = in_struct.coeffs.a1;
    b1 = in_struct.coeffs.b1;

    % Valores opcionales a2 y b2
    if isfield(in_struct.coeffs, 'a2') && ~isempty(in_struct.coeffs.a2)
        a2_default = in_struct.coeffs.a2;
    else
        a2_default = [];
    end
    if isfield(in_struct.coeffs, 'b2') && ~isempty(in_struct.coeffs.b2)
        b2_default = in_struct.coeffs.b2;
    else
        b2_default = [];
    end
    
    name_value_args = varargin;

else
    % Caso en el que el input son los vectores f, S, a1 y b1
    if numel(varargin) < 3
        error(['Si no se usa un struct de entrada, deben proporcionarse ', ...
               'f, S, a1 y b1.']);
    end

    f  = arg1;
    S  = varargin{1};
    a1 = varargin{2};
    b1 = varargin{3};

    a2_default = [];
    b2_default = [];

    if numel(varargin) > 3
        name_value_args = varargin(4:end);
    else
        name_value_args = {};
    end
end

%Valores por defecto
TotalBand_default = [];
Bands_default = struct();
CustomBands_default = struct();
IncludeDefaultBands_default = true;

%Input Parser
p = inputParser;
p.FunctionName = 'wsa_directional_parameters';

%Parámetros opcionales
addParameter(p, 'a2', a2_default, @(x) isempty(x) || isnumeric(x));
addParameter(p, 'b2', b2_default, @(x) isempty(x) || isnumeric(x));
addParameter(p, 'TotalBand', TotalBand_default, @(x) isempty(x) || wsa_is_valid_band(x));
addParameter(p, 'Bands', Bands_default, @(x) isstruct(x));
addParameter(p, 'CustomBands', CustomBands_default, @(x) isstruct(x));
addParameter(p, 'IncludeDefaultBands', IncludeDefaultBands_default, @(x) islogical(x) && isscalar(x));

parse(p, name_value_args{:});
opts = p.Results;

%Resultados
a2 = opts.a2;
b2 = opts.b2;

%% Verificaciones iniciales

if isempty(f)
    error('El vector de frecuencias f no puede estar vacío.');
end

if isempty(S)
    error('El vector espectral S no puede estar vacío.');
end

if isempty(a1) || isempty(b1)
    error('Los coeficientes a1 y b1 no pueden estar vacíos.');
end

if ~isnumeric(f) || ~isnumeric(S) || ~isnumeric(a1) || ~isnumeric(b1)
    error('f, S, a1 y b1 deben ser arreglos numéricos.');
end

% Convertir a vector columna
f  = f(:);
S  = S(:);
a1 = a1(:);
b1 = b1(:);

if ~isempty(a2)
    a2 = a2(:);
end

if ~isempty(b2)
    b2 = b2(:);
end

if xor(isempty(a2), isempty(b2))
    error('a2 y b2 deben especificarse conjuntamente.');
end

if numel(f) ~= numel(S) || numel(f) ~= numel(a1) || numel(f) ~= numel(b1)
    error('f, S, a1 y b1 deben tener la misma cantidad de elementos.');
end

if ~isempty(a2) && numel(f) ~= numel(a2)
    error('a2 debe tener la misma cantidad de elementos que f.');
end

if ~isempty(b2) && numel(f) ~= numel(b2)
    error('b2 debe tener la misma cantidad de elementos que f.');
end

if any(diff(f) <= 0)
    error('El vector de frecuencias f debe ser estrictamente creciente.');
end

if any(isnan(f)) || any(isnan(S)) || any(isnan(a1)) || any(isnan(b1))
    error('f, S, a1 y b1 no deben contener NaN.');
end

if any(~isfinite(f)) || any(~isfinite(S)) || any(~isfinite(a1)) || any(~isfinite(b1))
    error('f, S, a1 y b1 deben contener únicamente valores finitos.');
end

if ~isempty(a2) && (any(isnan(a2)) || any(~isfinite(a2)))
    error('a2 no debe contener NaN ni valores no finitos.');
end

if ~isempty(b2) && (any(isnan(b2)) || any(~isfinite(b2)))
    error('b2 no debe contener NaN ni valores no finitos.');
end




%% Definicion de bandas por defecto y struct final de bandas

%Bandas por defecto
default_bands = struct( ...
                        'ig', [1/300, 1/30], ...
                        'swell1', [1/30, 1/12.5], ...
                        'swell2', [1/12.5, 1/8], ...
                        'swell', [1/30, 1/8], ...
                        'wind', [1/8, 1/2] ...
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
    a1_total = a1;
    b1_total = b1;
    a2_total = a2;
    b2_total = b2;
    total_limits = [f(1), f(end)];                                          
else                                                                        % Usar nuevos limites si son especificados
    total_limits = opts.TotalBand;
    [f_total, S_total] = wsa_extract_band(f, S, total_limits);
    [~, a1_total] = wsa_extract_band(f, a1, total_limits);
    [~, b1_total] = wsa_extract_band(f, b1, total_limits);

    if ~isempty(a2) && ~isempty(b2)
        [~, a2_total] = wsa_extract_band(f, a2, total_limits);
        [~, b2_total] = wsa_extract_band(f, b2, total_limits);
    else
        a2_total = a2;
        b2_total = b2;
    end
end

main = wsa_band_directional_parameters(f_total, ...                         % Calcular parámetros totales
                                       S_total, ...
                                       a1_total, ...
                                       b1_total, ...
                                       a2_total, ...
                                       b2_total ...
                                       );                               
main.band_limits = total_limits;
main.used_spectra = struct('f', f_total, ...
                           'S', S_total, ...
                           'a1', a1_total, ...
                           'b1', b1_total, ...
                           'a2', a2_total, ...
                           'b2', b2_total ...
                           );

out_struct = main;

%% Cálculo por bandas de frecuencia

out_struct.bands = struct();
band_names = fieldnames(all_bands);

%Calcular parámetros para cada banda
for k = 1:numel(band_names)
    band_name = band_names{k};
    band_limits = all_bands.(band_name);

    [f_band, S_band] = wsa_extract_band(f, S, band_limits);
    [~, a1_band] = wsa_extract_band(f, a1, band_limits);
    [~, b1_band] = wsa_extract_band(f, b1, band_limits);

    if ~isempty(a2) && ~isempty(b2)
        [~, a2_band] = wsa_extract_band(f, a2, band_limits);
        [~, b2_band] = wsa_extract_band(f, b2, band_limits);
    else
        a2_band = a2;
        b2_band = b2;
    end

    band_out = wsa_band_directional_parameters(f_band, ...                         % Calcular parámetros por banda
                                               S_band, ...
                                               a1_band, ...
                                               b1_band, ...
                                               a2_band, ...
                                               b2_band ...
                                               );                         

    band_out.band_limits = band_limits;
    band_out.used_spectra = struct('f', f_band, ...
                                   'S', S_band, ...
                                   'a1', a1_band, ...
                                   'b1', b1_band, ...
                                   'a2', a2_band, ...
                                   'b2', b2_band ...
                                   );

    valid_name = matlab.lang.makeValidName(band_name);
    out_struct.bands.(valid_name) = band_out;
end

%Agregar banda total
out_struct.bands.total = main;

%% Adicionales

out_struct.band_definitions = all_bands;
out_struct.total_band_definition = total_limits;
out_struct.source_spectra = struct('f', f, ...
                                   'S', S, ...
                                   'a1', a1, ...
                                   'b1', b1, ...
                                   'a2', a2, ...
                                   'b2', b2);


end