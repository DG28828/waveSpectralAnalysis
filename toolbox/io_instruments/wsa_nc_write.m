function wsa_nc_write(data, ncfile, varargin)
%wsa_nc_write - exporta datos de instrumentos a formato netCDF.
%
%   Esta función exporta una estructura de datos AWAC a un archivo netCDF.
%   La estructura de entrada puede corresponder a datos crudos importados
%   mediante wsa_awac_read o a datos previamente limpiados mediante
%   wsa_awac_clean.
%
%   La función escribe en el archivo netCDF las variables principales de
%   los archivos .whd y .wad, incluyendo orientación del instrumento, 
%   presión, AST, velocidades orbitales, amplitudes, matriz de 
%   transformación y flags de control de calidad.
%
%   Además, se agregan atributos globales con información de la campaña,
%   sitio, instrumento, estado de limpieza y configuración básica de
%   muestreo.
%
%
%   Sintaxis:
%       wsa_awac_nc_write(data, ncfile)
%
%       wsa_awac_nc_write(data, ncfile, ...
%                       'site_name', site_name, ...
%                       'campaign_name', campaign_name)
%
%       wsa_awac_nc_write(data, ncfile, ...
%                       'site_name', site_name, ...
%                       'campaign_name', campaign_name, ...
%                       'mounting_height', mounting_height, ...
%                       'overwrite', true)
%
%
%   Argumentos de entrada (requeridos):
%       data    - Estructura de datos AWAC.
%                   Estructura generada por wsa_awac_read o
%                   wsa_awac_clean.
%
%       ncfile  - Ruta completa del archivo netCDF a crear.
%                   String | char.
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'site_name'
%               - Nombre del sitio de medición.
%                   String | char.
%                   Por defecto: "".
%
%       'campaign_name'
%               - Nombre de la campaña de medición.
%                   String | char.
%                   Por defecto: "".
%
%       'mounting_height'
%               - Altura de montaje del instrumento respecto al fondo.
%                   Escalar numérico (m).
%                   Por defecto: [].
%
%       'overwrite'
%               - Bandera para sobrescribir el archivo netCDF si ya existe.
%                   true | false
%                   Por defecto: true.
%
%
%   Argumentos de salida:
%       Esta función no devuelve argumentos de salida. El resultado se 
%       guarda directamente en el archivo especificado por ncfile.
%
%
%   Variables principales escritas en netCDF:
%
%       Variables dependientes de burst:
%           time
%           burst_counter
%           n_wave_records
%           cell_position
%           battery_voltage
%           sound_speed
%           heading
%           pitch
%           roll
%           min_pressure
%           max_pressure
%           temperature
%           cell_size
%           ast_window_start
%           ast_window_size
%           ast_window_offset
%
%       Variables dependientes de sample y burst:
%           pressure
%           ast
%           ast_quality
%           analog_input
%           velocity_beams
%           amplitude
%
%       Variables auxiliares:
%           noise_amp_beams
%           transformation_matrix
%
%       Variables de control de calidad:
%           samples_flag
%           size_flag
%           orientation_flag
%           pressure_flag
%           pressure_sample_flag
%           is_bad_burst
%           bad_tilt_flag
%           warning_tilt_flag
%
%
%   Notas:
%   • La función verifica que el struct de entrada contenga los campos whd
%     y wad.
%
%   • La cantidad de bursts en whd y wad debe coincidir.
%
%   • Si el archivo netCDF ya existe y overwrite = true, el archivo
%     existente se elimina antes de crear el nuevo archivo.
%
%   • Si el directorio de salida no existe, se crea automáticamente.
%
%   • El tiempo de cada burst se almacena como segundos POSIX:
%
%         seconds since 1970-01-01 00:00:00 UTC
%
%   • Si la estructura de entrada contiene información de limpieza, los
%     atributos globales time_start, time_end, cleaning_type y
%     Number_of_wave_measurements se toman de data.cleaning.
%
%   • Si la estructura de entrada no contiene información de limpieza, los
%     atributos globales anteriores se toman de data.quality.summary y
%     data.hdr.general.
%
%   • El atributo preprocessing_status se inicializa como false, ya que
%     esta función únicamente escribe datos crudos o limpios, pero no datos
%     preprocesados.
%
%   • El archivo resultante conserva las series temporales originales de
%     presión, AST y velocidades en coordenadas de beams. La transformación
%     a coordenadas ENU debe realizarse en una etapa posterior de
%     preprocesamiento.
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 10/03/2026
% Fecha de modificación: 30/07/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
site_name_default       = "";
campaign_name_default   = "";
overwrite_default       = true;
mounting_height_default = [];

%Input parser
p = inputParser;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'data');
addRequired(p, 'ncfile');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%
 addParameter(p, 'site_name', site_name_default, @(x) ischar(x) || isstring(x));
 addParameter(p, 'campaign_name', campaign_name_default, @(x) ischar(x) || isstring(x));
 addParameter(p, 'mounting_height', mounting_height_default, @(x) isnumeric(x));
 addParameter(p, 'overwrite', overwrite_default, @(x) islogical(x) && isscalar(x));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, data, ncfile, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
site_name       = string(p.Results.site_name);
campaign_name   = string(p.Results.campaign_name);
mounting_height = p.Results.mounting_height;
overwrite       = p.Results.overwrite;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Valores por defecto de fill y compresión
FILL_DOUBLE = double(9.969209968386869e36);
DEFLATE_LEVEL = 4;
SHUFFLE_FLAG = true;

%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('=============================          Escritura de datos de instrumento a formato netCDF         =============================\n');
fprintf('\nEscribir datos de instrumento a formato netCDF.\n');



% Detectar el tipo de instrumento
is_awac = isfield(data, 'whd') && isfield(data, 'wad');
is_aquadopp = isfield(data, 'dia_info') && isfield(data, 'dia');
if is_awac && is_aquadopp
    error('El struct contiene simultáneamente campos AWAC y AQUADOPP. No es posible determinar el instrumento.');
elseif is_awac
    instrument_type = "AWAC";
elseif is_aquadopp
    instrument_type = "AQUADOPP";
else
    error('No fue posible identificar el instrumento. Se esperaba:\n  AWAC: data.whd y data.wad\n  AQUADOPP: data.dia_info y data.dia');
end

% Crear nombres comunes para procesamiento
switch instrument_type

    case "AWAC"
        burst_info = data.whd;
        burst_data = data.wad;
        nSamples = data.hdr.setup.Wave_Number_of_samples;
        sampling_rate_Hz = data.hdr.setup.Wave_Sampling_rate_Hz;

    case "AQUADOPP"
        burst_info = data.dia_info;
        burst_data = data.dia;
        nSamples = data.hdr.setup.Diagnostics_Number_of_samples;
        sampling_rate_Hz = data.hdr.setup.Diagnostics_Sampling_rate_Hz;
end

% Cantidad de bursts
nBurst = numel(burst_info);
if numel(burst_data) ~= nBurst
    error('La cantidad de registros de información (%d) y series de ráfaga (%d) no coincide.', nBurst, numel(burst_data));
end

%Verificar que whd no este vacio
if nBurst == 0
    error('La estructura de datos reporta cero bursts.');
end

% AWAC: Verificar que whd y wad tenga la misma cantidad de bursts
if strcmp(instrument_type, "AWAC")
    nBurstData = numel(burst_data);
    if nBurstData ~= nBurst
        error('whd (%d) y wad (%d) no tienen la misma cantidad de bursts.', ...
            nBurst, nBurstData);
    end
end

%Verificar existencia de archivo y sobreescritura
if isfile(ncfile)

    if ~overwrite
        error('El archivo NetCDF ya existe: %s', ncfile);
    end

    try
        delete(ncfile);
    catch ME
        error(['No fue posible eliminar el archivo NetCDF existente:\n%s\n' ...
               'Puede estar abierto, bloqueado o no tener permisos de escritura.\n' ...
               'Mensaje original: %s'], ...
               ncfile, ME.message);
    end

    if isfile(ncfile)
        error(['El archivo NetCDF continúa existiendo después de intentar ' ...
               'eliminarlo:\n%s\nCierre cualquier programa que lo esté utilizando.'], ...
               ncfile);
    end
end

%Verificar existencia de directorio
outdir = fileparts(ncfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% Declarar variables
% En esta sección se declaran las variables a guardar en el archivo netCDF,
% con sus respectivos tamaños.

nAstSensors = 2;    % Número de mediciones AST (number of AST measurements)
nVelBeams = 3;         % Número de beams apra velocidad (number of velocities beams)
nBeams = 4;                % Número de beams (number of beams)
naxis = 3;                                                   % Ejes coordenados del equipo (X, Y, Z)
nAnalog_channels = 2;

% Variables de bursts
time = nan(nBurst,1);

burst_counter   = nan(nBurst,1);
n_wave_records  = nan(nBurst,1);
cell_position_m = nan(nBurst,1);

battery_voltage_V = nan(nBurst,1);
sound_speed_ms  = nan(nBurst,1);
heading_deg     = nan(nBurst,1);
pitch_deg       = nan(nBurst,1);
roll_deg        = nan(nBurst,1);
tilt_deg        = nan(nBurst,1);

min_pressure_dbar = nan(nBurst,1);
max_pressure_dbar = nan(nBurst,1);
temperature_degC = nan(nBurst,1);

cell_size_m     = nan(nBurst,1);
noise_amp_beams = nan(nBeams, nBurst);

ast_window_start_m  = nan(nBurst,1);
ast_window_size_m   = nan(nBurst,1);
ast_window_offset_m = nan(nBurst,1);


% Variables de muestras
pressure_dbar       = nan(nSamples, nBurst);
ast_distance_m      = nan(nSamples, nAstSensors, nBurst);
ast_quality         = nan(nSamples, nBurst);
analog_input        = nan(nSamples, nAnalog_channels, nBurst);
beam_velocity_ms    = nan(nSamples, nVelBeams, nBurst);
amplitude           = nan(nSamples, nVelBeams, nBurst);
error_code          = nan(nSamples,nBurst);
status_code         = nan(nSamples,nBurst);

% Definir variable nQC para tamaño de flags
if isfield(data, 'quality') && isfield(data.quality, 'flags')
    nQC = numel(data.quality.flags);
else
    nQC = nBurst;
end

% Variables de control de calidad
samples_flag            = nan(nQC,1);
size_flag               = nan(nQC,1);
orientation_flag        = nan(nQC,1);
pressure_flag           = nan(nQC,1);
pressure_sample_flag    = nan(nQC,1);
bad_tilt_flag           = nan(nQC,1);
warning_tilt_flag_5     = nan(nQC,1);
warning_tilt_flag_10    = nan(nQC,1);
warning_tilt_flag_20    = nan(nQC,1);

%% Extraer datos
% En esta sección se extraen los datos del struct de entrada, ya sea data
% (raw data) o data_clean (clean data).

%---------------          Datos de archivo .hdr          --------------- 
transformation_matrix = data.hdr.head_configuration.Transformation_matrix;

%Extraer datos de burst y muestras por burst

for i = 1:nBurst

    bi = burst_info(i);
    bd = burst_data(i);

    % Tiempo
    time(i) = wsa_datetime2posix(wsa_get_struct_field(bi, 'datetime'));

    % Variables comunes de burst
    n_wave_records(i) = get_scalar_field(bi, 'n_wave_records');
    if isnan(n_wave_records(i))
        n_wave_records(i) = get_scalar_field(bi, 'n_diagnostic_records');
    end

    % Variables comunes
    burst_counter(i)      = get_scalar_field(bi, 'burst_counter');
    if isnan(burst_counter(i))
        tmp_counter = wsa_get_struct_field(bd, 'burst_counter');
        if ~isempty(tmp_counter)
            burst_counter(i) = ...
                double(tmp_counter(1));
        end
    end
    battery_voltage_V(i) = get_scalar_field(bi, 'battery_voltage_V');
    sound_speed_ms(i)     = get_scalar_field(bi, 'sound_speed_ms');
    heading_deg(i)        = get_scalar_field(bi, 'heading_deg');
    pitch_deg(i)          = get_scalar_field(bi, 'pitch_deg');
    roll_deg(i)           = get_scalar_field(bi, 'roll_deg');
    tilt_deg(i)           = get_scalar_field(bi, 'tilt_deg');
    min_pressure_dbar(i)  = get_scalar_field(bi, 'min_pressure_dbar');
    max_pressure_dbar(i)  = get_scalar_field(bi, 'max_pressure_dbar');
    temperature_degC(i)   = get_scalar_field(bi, 'temperature_degC');
    

    % Variables exclusivas del AWAC
    cell_position_m(i)    = get_scalar_field(bi, 'cell_position_m');
    cell_size_m(i)        = get_scalar_field(bi, 'cell_size_m');
    ast_window_start_m(i) = get_scalar_field(bi, 'ast_window_start_m');
    ast_window_size_m(i)  = get_scalar_field(bi, 'ast_window_size_m');
    ast_window_offset_m(i)= get_scalar_field(bi, 'ast_window_offset_m');


    
    tmp_noise = wsa_get_struct_field(bi, 'noise_amp_beams');
    if ~isempty(tmp_noise)
        n = min(nBeams,numel(tmp_noise));
        noise_amp_beams(1:n,i) = ...
            double(tmp_noise(1:n));
    end

    % Presión
    tmp = wsa_get_struct_field(bd, 'pressure_dbar');
    if ~isempty(tmp)
        tmp = double(tmp(:));
        nr = min(nSamples,numel(tmp));
        pressure_dbar(1:nr,i) = tmp(1:nr);
    end

    % Velocidades
    tmp = wsa_get_struct_field(bd, 'beam_velocity_ms');
    if ~isempty(tmp)
        tmp = double(tmp);
        nr = min(nSamples,size(tmp,1));
        nc = min(nVelBeams,size(tmp,2));

        beam_velocity_ms(1:nr,1:nc,i) = ...
            tmp(1:nr,1:nc);
    end

    % Amplitudes
    tmp = wsa_get_struct_field(bd, 'amplitude');
    if ~isempty(tmp)
        tmp = double(tmp);
        nr = min(nSamples,size(tmp,1));
        nc = min(nVelBeams,size(tmp,2));

        amplitude(1:nr,1:nc,i) = tmp(1:nr,1:nc);
    end

    % AST, solo AWAC
    tmp = wsa_get_struct_field(bd, 'ast_distance_m');
    if ~isempty(tmp)
        tmp = double(tmp);
        nr = min(nSamples,size(tmp,1));
        nc = min(nAstSensors,size(tmp,2));

        ast_distance_m(1:nr,1:nc,i) = tmp(1:nr,1:nc);
    end
    tmp = wsa_get_struct_field(bd, 'ast_quality');
    if ~isempty(tmp)
        tmp = double(tmp(:));
        nr = min(nSamples,numel(tmp));
        ast_quality(1:nr,i) = tmp(1:nr);
    end

    % Entradas analógicas
    if instrument_type == "AWAC"

        tmp = wsa_get_struct_field( bd, 'analog_input');
        if ~isempty(tmp)
            tmp = double(tmp(:));
            nr = min(nSamples,numel(tmp));

            analog_input(1:nr,1,i) = tmp(1:nr);
        end

    else
        tmp1 = wsa_get_struct_field(bd, 'analog1');
        tmp2 = wsa_get_struct_field(bd, 'analog2');
        if ~isempty(tmp1)
            tmp1 = double(tmp1(:));
            nr = min(nSamples,numel(tmp1));
            analog_input(1:nr,1,i) = tmp1(1:nr);
        end
        if ~isempty(tmp2)
            tmp2 = double(tmp2(:));
            nr = min(nSamples,numel(tmp2));
            analog_input(1:nr,2,i) = tmp2(1:nr);
        end
    end

    % Códigos Aquadopp
    tmp = wsa_get_struct_field(bd, 'error_code');
    if ~isempty(tmp)
        tmp = double(tmp(:));
        nr = min(nSamples,numel(tmp));
        error_code(1:nr,i) = tmp(1:nr);
    end

    tmp = wsa_get_struct_field(bd, 'status_code');
    if ~isempty(tmp)
        tmp = double(tmp(:));
        nr = min(nSamples,numel(tmp));
        status_code(1:nr,i) = tmp(1:nr);
    end
end


%------------       Datos de archivo calidad de los datos       ----------- 
if isfield(data, 'quality') && isfield(data.quality, 'flags')
    nQC = numel(data.quality.flags);

for i = 1:nQC

    qf = data.quality.flags(i);

    samples_flag(i) = get_scalar_field(qf, 'samples_flag');
    size_flag(i) = get_scalar_field(qf, 'size_flag');
    orientation_flag(i) = get_scalar_field(qf, 'orientation_flag');
    pressure_flag(i) = get_scalar_field(qf, 'pressure_flag');
    pressure_sample_flag(i) = get_scalar_field(qf, 'pressure_sample_flag');
    bad_tilt_flag(i) = get_scalar_field(qf, 'bad_tilt_flag');
    warning_tilt_flag_5(i) = get_scalar_field(qf, 'warning_tilt_flag_5');
    warning_tilt_flag_10(i) = get_scalar_field(qf, 'warning_tilt_flag_10');
    warning_tilt_flag_20(i) = get_scalar_field(qf, 'warning_tilt_flag_20');
end
end



% Recuperar flags is_bad_burst aplicada durante la limpieza
if isfield(data, 'cleaning') && isfield(data.cleaning, 'is_bad_burst')
    is_bad_burst = logical(data.cleaning.is_bad_burst(:));

elseif isfield(data, 'quality') && isfield(data.quality, 'summary') && isfield(data.quality.summary, 'bad_bursts')
    is_bad_burst = logical(data.quality.summary.bad_bursts(:));

else
    warning('No se encontró la máscara is_bad_burst. Se asumirá que ninguna ráfaga fue eliminada.');
    is_bad_burst = false(nQC,1);
end

% Verificar longitud respecto a burst_raw
if numel(is_bad_burst) ~= nQC
    error('La máscara is_bad_burst contiene %d elementos, pero quality.flags contiene %d elementos.', numel(is_bad_burst), nQC);
end

% Verificar correspondencia entre burst_raw y burst
if isfield(data, 'cleaning_status') && data.cleaning_status
    nGood = sum(~is_bad_burst);
    if nGood ~= nBurst
        error('Las banderas de limpieza indican %d ráfagas válidas, pero burst_info y burst_data contienen %d ráfagas.', nGood, nBurst);
    end

else
    % En datos sin limpiar, burst y burst_raw deberían coincidir
    if nQC ~= nBurst
        error(['Los datos no están marcados como limpios, pero existen ' ...
               '%d ráfagas en quality.flags y %d en burst_info.'], ...
               nQC, nBurst);
    end
end

% Convertir para guardar como double 0/1
is_bad_burst = double(is_bad_burst);


%% Crear dimensiones y variables para netCDF
% En esta sección se crean las variables para el archivo netCDF, donde se
% especifican sus propiedades: nombre, dimensiones, tipo y atributos.


%---------     Variables dependientes de la dimensión {burst}     ---------

%Variable tiempo
wsa_nc_create_var( ...
                   ncfile, ...                                              %ncfile
                  'time', ...                                               %varname
                  {'burst', nBurst}, ...                                    %dims
                  'double', ...                                             %datatype
                  'units', 'seconds since 1970-01-01 00:00:00 UTC', ...     %varargin1, value (unidad)
                  'long_name', 'burst time' ...                             %varargin2, value (nombre largo)
                  );

% Variables de whd: nombre, valor, tipo de dato, unidad, nombre largo
vars1d_burst = {
    'burst_counter',        burst_counter,      'double',   'count',      'burst_counter';              %whd
    'n_wave_records',       n_wave_records,     'double',   'count',      'number_of_wave_records';     %whd
    'cell_position',        cell_position_m,    'double',   'm',          'cell_position_m';            %whd
    'battery_voltage',      battery_voltage_V,  'double',   'V',          'battery_voltage_V';          %whd
    'sound_speed',          sound_speed_ms,     'double',   'm/s',        'sound_speed_ms';             %whd
    'heading',              heading_deg,        'double',   'degree',     'heading_deg';                %whd
    'pitch',                pitch_deg,          'double',   'degree',     'pitch_deg';                  %whd
    'roll',                 roll_deg,           'double',   'degree',     'roll_deg';                   %whd
    'tilt',                 tilt_deg,           'double',   'degree',     'tilt_deg';                   %whd
    'min_pressure',         min_pressure_dbar,  'double',   'dbar',       'min_pressure_dbar';          %whd
    'max_pressure',         max_pressure_dbar,  'double',   'dbar',       'max_pressure_dbar';          %whd
    'temperature',          temperature_degC,   'double',   'degree_C',   'temperature_degC';           %whd
    'cell_size',            cell_size_m,        'double',   'm',          'cell_size_m';                %whd
    'ast_window_start',     ast_window_start_m, 'double',   'm',          'ast_window_start_m';         %whd
    'ast_window_size',      ast_window_size_m,  'double',   'm',          'ast_window_size_m';          %whd
    'ast_window_offset',    ast_window_offset_m,'double',   'm',          'ast_window_offset_m';        %whd
    };
for k = 1:size(vars1d_burst,1)
    name  = vars1d_burst{k,1};
    dtype = vars1d_burst{k,3};
    units = vars1d_burst{k,4};
    long_name = vars1d_burst{k, 5};
    wsa_nc_create_var( ...
                       ncfile, ...                  %ncfile
                       name, ...                    %varname
                       {'burst', nBurst}, ...       %dims
                       dtype, ...                   %datatype
                       'units', units, ...          %varargin1, value (unidad)
                       'long_name', long_name ...        %varargin2, value (nombre_largo)
                        );
end

%-------     Variables dependientes de la dimensión {burst_raw}     -------
vars1d_burst_raw = {
    'samples_flag',         samples_flag,           'double',   'bool',       'samples_flag';
    'size_flag',            size_flag,              'double',   'bool',       'size_flag';
    'orientation_flag',     orientation_flag,       'double',   'bool',       'orientation_flag';
    'pressure_flag',        pressure_flag,          'double',   'bool',       'pressure_flag';
    'pressure_sample_flag', pressure_sample_flag,   'double',   'bool',       'pressure_sample_flag';
    'is_bad_burst',         is_bad_burst,           'double',   'bool',       'is_bad_burst';
    'bad_tilt_flag',        bad_tilt_flag,          'double',   'bool',       'bad_tilt_flag';
    'warning_tilt_flag_5',    warning_tilt_flag_5,      'double',   'bool',       'warning_tilt_flag_5';
    'warning_tilt_flag_10',    warning_tilt_flag_10,      'double',   'bool',       'warning_tilt_flag_10';
    'warning_tilt_flag_20',    warning_tilt_flag_20,      'double',   'bool',       'warning_tilt_flag_20';
    };
for k = 1:size(vars1d_burst_raw,1)
    name  = vars1d_burst_raw{k,1};
    dtype = vars1d_burst_raw{k,3};
    units = vars1d_burst_raw{k,4};
    long_name = vars1d_burst_raw{k, 5};
    wsa_nc_create_var( ...
                       ncfile, ...                  %ncfile
                       name, ...                    %varname
                       {'burst_raw', nQC}, ...       %dims
                       dtype, ...                   %datatype
                       'units', units, ...          %varargin1, value (unidad)
                       'long_name', long_name ...        %varargin2, value (nombre_largo)
                        );
end



%-------     Variables 2D     -------

% pressure(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'pressure', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'dbar', ...
                  'long_name', 'pressure (dbar)', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), 1] ...
                  );

% ast_distance(sample, ast_sensor, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'ast', ...
                  {'sample', nSamples, 'ast_sensor', nAstSensors, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'm', ...
                  'long_name', 'ast distance (m)', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), nAstSensors, 1] ...
                  );

% velocity_beams(sample, vel_beam, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'velocity_beams', ...
                  {'sample', nSamples, 'vel_beam', nVelBeams, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'm/s', ...
                  'long_name', 'orbital velocity along beam (m/s)', ...
                  'description', 'Axes: Beam 1, Beam 2, Beam 3', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), nVelBeams, 1] ...
                  );

% amplitude(sample, vel_beam, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'amplitude', ...
                  {'sample', nSamples, 'vel_beam', nVelBeams, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'count', ...
                  'long_name', 'signal amplitude (counts)', ...
                  'description', 'Axes: (Beam 1), (Beam 2), (Beam 3)', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), nVelBeams, 1] ...
                  );

% noise_amp_beams(beam , burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'noise_amp_beams', ...
                  {'beam', nBeams, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'count', ...
                  'long_name', 'noise amplitude (counts)', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [nBeams, 1] ...
                  );

% ast_quality(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'ast_quality', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'double', ...
                  'units', '1', ...
                  'long_name', 'ast quality', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), 1] ...
                  );

% analog_input(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'analog_input', ...
                  {'sample', nSamples, 'analog_channel', nAnalog_channels, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'count', ...
                  'long_name', 'analog input', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), nAnalog_channels, 1] ...
                  );

%Transformation matrix(axis, beam)
wsa_nc_create_var( ...
                  ncfile, ...
                  'transformation_matrix', ...
                  {'axis', naxis, 'vel_beam', nVelBeams}, ...
                  'double', ...
                  'units', '', ...
                  'long_name', 'Transformation matrix for velocities' ...
                  );

wsa_nc_create_var( ...
                  ncfile, ...
                  'error_code', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'double', ...
                  'units', '1', ...
                  'long_name', 'instrument error code', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), 1] ...
                  );

wsa_nc_create_var( ...
                  ncfile, ...
                  'status_code', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'double', ...
                  'units', '1', ...
                  'long_name', 'instrument status code', ...
                  'FillValue', FILL_DOUBLE, ...
                  'DeflateLevel', DEFLATE_LEVEL, ...
                  'Shuffle', SHUFFLE_FLAG, ...
                  'ChunkSize', [min(nSamples,1024), 1] ...
                  );


%% Escribir datos

ncwrite(ncfile, 'time', time);

for k = 1:size(vars1d_burst,1)
    name = vars1d_burst{k,1};
    val  = vars1d_burst{k,2};
    ncwrite(ncfile, name, double(val));
end

for k = 1:size(vars1d_burst_raw,1)
    name = vars1d_burst_raw{k,1};
    val  = vars1d_burst_raw{k,2};
    ncwrite(ncfile, name, double(val));
end

write_numeric_with_fill(ncfile, 'noise_amp_beams', noise_amp_beams, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'pressure', pressure_dbar, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'ast', ast_distance_m, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'ast_quality', ast_quality, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'analog_input', analog_input, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'velocity_beams', beam_velocity_ms, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'amplitude', amplitude, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'transformation_matrix', transformation_matrix, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'error_code', error_code, FILL_DOUBLE);
write_numeric_with_fill(ncfile, 'status_code', status_code, FILL_DOUBLE);

%% Atributos globales

ncwriteatt(ncfile, '/', 'title', sprintf('%s campaign data', instrument_type));
ncwriteatt(ncfile, '/', 'id', [char(site_name), '_', char(campaign_name)])
ncwriteatt(ncfile, '/', 'site', char(site_name));
ncwriteatt(ncfile, '/', 'campaign', char(campaign_name));


if isfield(data, 'cleaning')
    ncwriteatt(ncfile, '/', 'time_start', char(string(data.cleaning.time_start)));
else
    ncwriteatt(ncfile, '/', 'time_start', char(string(data.quality.summary.time_start)));
end

if isfield(data, 'cleaning')
    ncwriteatt(ncfile, '/', 'time_end', char(string(data.cleaning.time_end)));
else
    ncwriteatt(ncfile, '/', 'time_end', char(string(data.quality.summary.time_end)));
end

ncwriteatt(ncfile, '/', 'instrument_type', char(instrument_type));
ncwriteatt(ncfile, '/', 'instrument_serial', char(data.hdr.hardware_configuration.Serial_number));
ncwriteatt(ncfile, '/', 'head_serial', char(data.hdr.head_configuration.Serial_number));


if ~isempty(mounting_height)
    ncwriteatt(ncfile, '/', 'mounting_height_m', mounting_height);
else
    ncwriteatt(ncfile, '/', 'mounting_height_m', 'not specified');
end

ncwriteatt(ncfile, '/', 'coordinate_system', char(data.hdr.setup.Coordinate_system));
ncwriteatt(ncfile, '/', 'blanking_distance_m', double(data.hdr.setup.Blanking_distance_m));


ncwriteatt(ncfile, '/', 'cleaning_status', double(data.cleaning_status));
ncwriteatt(ncfile, '/', 'preprocessing_status', double(false));

if isfield(data, 'cleaning')
    ncwriteatt(ncfile, '/', 'cleaning_type', char(string(data.cleaning.cleaning_type)));
else
    ncwriteatt(ncfile, '/', 'cleaning_type', 'cleaning not applied');
end



ncwriteatt(ncfile, '/', 'number_of_bursts', double(nBurst));


if isfield(data, 'hdr')
    gi = data.hdr;

    if isfinite(sampling_rate_Hz) && sampling_rate_Hz > 0
        ncwriteatt(ncfile, '/', 'sampling_rate_Hz', double(sampling_rate_Hz));
    else
        error('No se dispone de una frecuencia de muestreo válida.');
    end
    
    if isfinite(nSamples) && nSamples > 0
        ncwriteatt(ncfile, '/', 'number_of_samples', double(nSamples));
    else
        error('No se dispone de un número de muestras válido.');
    end

    if isfield(gi, 'general') && isfield(gi.general, 'Time_of_first_measurement')
        ncwriteatt(ncfile, '/', 'raw_data_time_of_first_measurement', ...
            char(string(gi.general.Time_of_first_measurement)));
    end

    if isfield(gi, 'general') && isfield(gi.general, 'Time_of_last_measurement')
        ncwriteatt(ncfile, '/', 'raw_data_time_of_last_measurement', ...
            char(string(gi.general.Time_of_last_measurement)));
    end
end

switch instrument_type
    case "AWAC"
        burst_interval_s = wsa_get_struct_field(data.hdr.setup, 'Wave_Interval_s');
        burst_duration_s = wsa_get_struct_field(data.hdr.setup, 'Wave_burst_duration_s');

    case "AQUADOPP"
        burst_interval_s = wsa_get_struct_field(data.hdr.setup, 'Diagnostics_Interval_s');
        burst_duration_s = wsa_get_struct_field(data.hdr.setup, 'Diagnostics_burst_duration_s');
end
ncwriteatt(ncfile, '/', 'burst_interval_s', double(burst_interval_s));
ncwriteatt(ncfile, '/', 'burst_duration_s', double(burst_duration_s));


ncwriteatt(ncfile, '/', 'source', 'WSA toolbox');


fprintf('\nArchivo escrito correctamente.\n');

fprintf('\n========================================================================================================================\n');




function value = get_scalar_field(s, field_name, default_value)

if nargin < 3
    default_value = NaN;
end

if ~isstruct(s) || ~isfield(s, field_name)
    value = default_value;
    return
end

value = s.(field_name);

if isempty(value) || ~(isnumeric(value) || islogical(value)) || ~isscalar(value)
    value = default_value;
else
    value = double(value);
end

end

function write_numeric_with_fill(ncfile, varname, data, fill_value)

data = double(data);

% Si la variable está completamente vacía y acaba de crearse,
% se conserva sin escribir. NetCDF devolverá _FillValue.
if all(~isfinite(data(:)))
    return
end

% Sustituir faltantes parciales por _FillValue.
data(~isfinite(data)) = fill_value;

ncwrite(ncfile, varname, data);

end



end