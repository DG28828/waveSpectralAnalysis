function data = wsa_rbr_read(files_dir, varargin)
%wsa_rbr_read - lectura y verificación de calidad de datos RBR.
%
%   Esta función importa datos de presión medidos por instrumentos RBR a
%   partir de los archivos de texto exportados por Ruskin.
%
%   Para mantener la lectura limitada a la información necesaria para el
%   procesamiento posterior, únicamente se utilizan:
%
%       *_metadata.txt   Metadatos del instrumento y configuración de muestreo.
%       *_burst.txt      Series de presión de cada burst.
%
%   Los archivos *_data.txt, *_events.txt y *_wave.txt no se utilizan,
%   porque contienen datos resumidos, eventos o productos de oleaje
%   calculados por Ruskin que pueden reconstruirse en etapas posteriores.
%
%   La función conserva la presión absoluta exportada por Ruskin en dbar y
%   organiza las mediciones en bursts. Además, realiza verificaciones de:
%
%       1) número de muestras e intervalo temporal dentro de cada burst;
%       2) presión media respecto a un mínimo y a la mediana de la campaña;
%       3) porcentaje de muestras inválidas o inferiores al mínimo.
%
%
%   Sintaxis:
%       data = wsa_rbr_read(files_dir)
%
%       data = wsa_rbr_read(files_dir, ...
%               'min_pressure_limit', 1, ...
%               'pressure_drop_limit', 5, ...
%               'bad_pressure_sample_percentage_limit', 5)
%
%       data = wsa_rbr_read(files_dir, 'do_plot', true)
%
%
%   Argumentos de entrada (requeridos):
%       files_dir  - Directorio que contiene los archivos exportados por
%                    Ruskin. String escalar o vector char.
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'min_pressure_limit'
%                  - Presión absoluta mínima permitida.
%                    Escalar finito (dbar).
%                    Por defecto: 1 dbar.
%
%       'pressure_drop_limit'
%                  - Diferencia máxima permitida entre la presión media de
%                    cada burst y la mediana de la campaña.
%                    Escalar no negativo (dbar).
%                    Por defecto: 5 dbar.
%
%       'bad_pressure_sample_percentage_limit'
%                  - Porcentaje máximo permitido de muestras inválidas o
%                    inferiores a min_pressure_limit dentro de un burst.
%                    Escalar entre 0 y 100 (%).
%                    Por defecto: 5 %.
%
%       'do_plot'  - Generar figuras de control de calidad.
%                    true | false. Por defecto: false.
%
%       'save_plot_dir'
%                  - Directorio donde se guardarán las figuras. Cuando se
%                    especifica, do_plot se activa automáticamente.
%                    Por defecto: vacío.
%
%
%   Argumento de salida:
%       data       - Estructura con los campos principales:
%
%           hdr         Metadatos seleccionados del instrumento, Ruskin,
%                       configuración de muestreo y archivos utilizados.
%
%           rbr_info    Información escalar por burst:
%                       burst_index, burst_counter, datetime, end_datetime,
%                       n_wave_records y estadísticas de presión.
%
%           rbr         Series por burst:
%                       burst_counter, pressure_dbar y nSamples.
%
%           quality     Flags y resumen de control de calidad.
%
%           cleaning_status       false al finalizar la lectura.
%           preprocessing_status  false al finalizar la lectura.
%
%
%   Notas:
%   • Los tiempos se conservan tal como aparecen en el archivo *_burst.txt,
%     sin asignar una zona horaria. El desfase UTC indicado por Ruskin se
%     guarda en data.hdr.setup.Time_offset_from_UTC_hours.
%
%   • No se almacena un vector datetime por muestra. Los tiempos de muestra
%     pueden reconstruirse a partir del inicio del burst y la frecuencia de
%     muestreo.
%
%   • La columna Wave del archivo *_burst.txt se ignora ya que corresponde a un producto derivado por Ruskin.
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/08/2026
% Fecha de modificación: 05/08/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Input parser
p = inputParser;
p.FunctionName = mfilename;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'files_dir', @(x) ischar(x) || (isstring(x) && isscalar(x)));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%
addParameter(p, 'min_pressure_limit', 1, @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'pressure_drop_limit', 5, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
addParameter(p, 'bad_pressure_sample_percentage_limit', 5, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x <= 100);
addParameter(p, 'do_plot', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'save_plot_dir', [], @(x) isempty(x) || ischar(x) || (isstring(x) && isscalar(x)));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, files_dir, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
files_dir = char(string(p.Results.files_dir));
min_pressure_limit = double(p.Results.min_pressure_limit);
pressure_drop_limit = double(p.Results.pressure_drop_limit);
bad_pressure_sample_percentage_limit = double(p.Results.bad_pressure_sample_percentage_limit);
do_plot = p.Results.do_plot;
save_plot_dir = p.Results.save_plot_dir;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('=============================================          Lectura de RBR          =============================================\n');
fprintf('\nLeer datos de presión de RBR.\n');

if ~isfolder(files_dir)
    error('La carpeta no existe: %s', files_dir);
end

if ~isempty(save_plot_dir)
    save_plot_dir = char(string(save_plot_dir));
    do_plot = true;

    if ~isfolder(save_plot_dir)
        mkdir(save_plot_dir);
    end
end

[file_burst, file_metadata, deployment_name] = locate_rbr_files(files_dir);

fprintf('\nArchivo de bursts:\n%s\n', file_burst);
fprintf('\nArchivo de metadatos:\n%s\n', file_metadata);

%% Leer y verificar metadatos de Ruskin

fprintf('\n----------------------------          Extrayendo metadatos de Ruskin          ----------------------------\n');

try
    metadata = jsondecode(fileread(file_metadata));

catch ME
    error('No fue posible leer el archivo de metadatos JSON:\n%s\n%s', ...
        file_metadata, ME.message);
end

required_metadata_blocks = {'instrument', 'sampling'};

for k = 1:numel(required_metadata_blocks)

    field_name = required_metadata_blocks{k};

    if ~isfield(metadata, field_name) || ~isstruct(metadata.(field_name))
        error('El archivo de metadatos no contiene el bloque requerido "%s".', field_name);
    end
end

sampling_period_ms = get_numeric_field(metadata.sampling, 'period', NaN);
expected_nSamples = get_numeric_field(metadata.sampling, 'burstcount', NaN);
burst_interval_ms = get_numeric_field(metadata.sampling, 'burstinterval', NaN);
atmpressure_dbar = get_numeric_field(metadata.parameters, 'atmpressure', NaN);

if ~isfinite(sampling_period_ms) || sampling_period_ms <= 0
    error('metadata.sampling.period no contiene un periodo de muestreo válido.');
end

if ~isfinite(expected_nSamples) || expected_nSamples <= 0 || expected_nSamples ~= fix(expected_nSamples)
    error('metadata.sampling.burstcount no contiene un número entero positivo de muestras.');
end

if ~isfinite(burst_interval_ms) || burst_interval_ms <= 0
    error('metadata.sampling.burstinterval no contiene un intervalo de burst válido.');
end

if ~isfinite(atmpressure_dbar)
    error('metadata.parameters.atmpressure no contiene un valor numérico válido.');
end

sampling_interval_s = sampling_period_ms/1000;
sampling_rate_Hz = 1/sampling_interval_s;
burst_interval_s = burst_interval_ms/1000;
burst_duration_s = expected_nSamples/sampling_rate_Hz;

pressure_units = find_channel_units(metadata, 'burstheader', 'Pressure');

if strlength(pressure_units) > 0 && ~strcmpi(pressure_units, "dbar")
    error('La función espera presión exportada en dbar, pero los metadatos indican unidades "%s".', pressure_units);

elseif strlength(pressure_units) == 0
    warning('No fue posible verificar las unidades de presión en los metadatos. La columna Pressure se interpretará como dbar.');
    pressure_units = "dbar";

end

fprintf('\nInstrumento: %s\n', char(string(get_field_default(metadata.instrument, 'model', ""))));
fprintf('Número de serie: %s\n', char(string(get_field_default(metadata.instrument, 'serial', ""))));
fprintf('Frecuencia de muestreo: %.6g Hz\n', sampling_rate_Hz);
fprintf('Muestras esperadas por burst: %d\n', expected_nSamples);
fprintf('Intervalo entre bursts: %.6g s\n', burst_interval_s);

%% Leer archivo de bursts

fprintf('\n----------------------------          Extrayendo series de presión          ----------------------------\n');

[time_all, burst_counter_all, pressure_all] = ...
    read_rbr_burst_file(file_burst);

nRows = numel(pressure_all);

if nRows == 0
    error('El archivo de bursts no contiene registros de presión.');
end

if numel(time_all) ~= nRows || ...
        numel(burst_counter_all) ~= nRows

    error('Las columnas Time, Burst y Pressure no tienen la misma longitud.');
end

if any(~isfinite(burst_counter_all)) || ...
        any(burst_counter_all ~= fix(burst_counter_all))

    error('La columna Burst contiene identificadores no enteros o no finitos.');
end

if any(diff(burst_counter_all) < 0)
    error('La columna Burst no está ordenada de forma ascendente.');
end

burst_start_idx = find([true; diff(burst_counter_all) ~= 0]);

burst_end_idx = [
    burst_start_idx(2:end) - 1
    nRows
];

burst_ids = burst_counter_all(burst_start_idx);
nBursts = numel(burst_ids);

if numel(unique(burst_ids)) ~= nBursts
    error('Un mismo identificador de burst aparece en bloques no contiguos.');
end

%% Organizar datos por burst y verificar muestreo

empty_rbr = struct( ...
                    'burst_counter', [], ...
                    'pressure_dbar', [], ...
                    'nSamples', []);

data.rbr = repmat(empty_rbr, nBursts, 1);

empty_info = struct( ...
                    'burst_index', [], ...
                    'burst_counter', [], ...
                    'datetime', NaT, ...
                    'end_datetime', NaT, ...
                    'n_wave_records', [], ...
                    'mean_pressure_dbar', NaN, ...
                    'min_pressure_dbar', NaN, ...
                    'max_pressure_dbar', NaN);

data.rbr_info = repmat(empty_info, nBursts, 1);

samples_flag = false(nBursts, 1);
actual_samples = zeros(nBursts, 1);
time_interval_flag = false(nBursts, 1);
bad_pressure_sample_percentage = NaN(nBursts, 1);

sample_time_tolerance_s = max(1e-6, sampling_interval_s * 1e-5);

for b = 1:nBursts

    idx = burst_start_idx(b):burst_end_idx(b);

    time_b = time_all(idx);
    pressure_b = double(pressure_all(idx));
    burst_counter = double(burst_ids(b));
    nSamples_b = numel(idx);

    actual_samples(b) = nSamples_b;

    % Verificar intervalo temporal dentro del burst.
    if nSamples_b > 1

        dt_b = seconds(diff(time_b));

        time_interval_flag(b) = any(~isfinite(dt_b)) || any(abs(dt_b - sampling_interval_s) > sample_time_tolerance_s);

    else
        time_interval_flag(b) = true;
    end

    samples_flag(b) = nSamples_b ~= expected_nSamples || time_interval_flag(b);

    data.rbr(b).burst_counter = burst_counter;
    data.rbr(b).pressure_dbar = pressure_b(:);
    data.rbr(b).nSamples = nSamples_b;

    data.rbr_info(b).burst_index = b;
    data.rbr_info(b).burst_counter = burst_counter;
    data.rbr_info(b).datetime = time_b(1);
    data.rbr_info(b).end_datetime = time_b(end);
    data.rbr_info(b).n_wave_records = nSamples_b;

    data.rbr_info(b).mean_pressure_dbar = mean(pressure_b, 'omitnan');

    data.rbr_info(b).min_pressure_dbar = min(pressure_b, [], 'omitnan');

    data.rbr_info(b).max_pressure_dbar = max(pressure_b, [], 'omitnan');

    invalid_pressure_samples = ~isfinite(pressure_b) | pressure_b < min_pressure_limit;

    bad_pressure_sample_percentage(b) = 100*sum(invalid_pressure_samples)/nSamples_b;
end

burst_start_time = [data.rbr_info.datetime]';
burst_end_time = [data.rbr_info.end_datetime]';

% Las columnas completas ya fueron distribuidas por burst. Se liberan para
% reducir el pico de memoria antes de construir el resto del struct.
clear time_all burst_counter_all pressure_all

% Verificar intervalos entre inicios considerando el cambio del contador.
if nBursts > 1

    observed_start_interval_s = seconds(diff(burst_start_time));

    expected_start_interval_s = diff(burst_ids) * burst_interval_s;

    burst_time_mismatch = abs(observed_start_interval_s - expected_start_interval_s) > max(1e-3, sampling_interval_s);

    if any(burst_time_mismatch)

        warning('Se detectaron %d intervalos entre bursts que no coinciden con el contador y el intervalo indicado en los metadatos.', sum(burst_time_mismatch));
    end

else
    burst_time_mismatch = false(0,1);
end

fprintf('\nBursts detectados: %d\n', nBursts);
fprintf('Registros de presión leídos: %d\n', nRows);

fprintf('Bursts con número de muestras o intervalo temporal irregular: %d\n', sum(samples_flag));

%% Verificación de presión

% Convertir límite a presión absoluta, ya que los datos crudos de presión
% son de presión absoluta
min_pressure_limit_abs = min_pressure_limit + atmpressure_dbar;

fprintf('\n----------------------------          Verificación de presión          ----------------------------\n');
fprintf('\nLímites establecidos:\n');
fprintf('\t-Presión mínima (absoluta): %.4g dbar\n', min_pressure_limit_abs);
fprintf('\t-Diferencia respecto a la mediana: %.4g dbar\n', pressure_drop_limit);
fprintf('\t-Porcentaje máximo de muestras inválidas o bajas: %.4g %%\n', bad_pressure_sample_percentage_limit);

% Se realiza una verificación de la presión siguiendo los siguientes
% criterios:
%
%   1) Presión media del burst
%       Se verifica la presión media del burst y se compara con una presión
%       mínima y límites +-mediana. Se marca el burst si la presión mínima
%       supera alguno de los criterios.
%
%   2) Porcentaje de samples de presión por debajo de umbral
%       Se verifica, para cada burst, la cantidad de samples que se
%       encuentran debajo del umbral establecido. Se elimina el burst si la
%       cantidad de samples de baja presión superan un porcentaje deseado.

mean_pressure = [data.rbr_info.mean_pressure_dbar]';
median_pressure = median(mean_pressure, 'omitnan');

pressure_flag = ~isfinite(mean_pressure) | mean_pressure < min_pressure_limit_abs | abs(mean_pressure - median_pressure) > pressure_drop_limit;

pressure_sample_flag = bad_pressure_sample_percentage > bad_pressure_sample_percentage_limit;

fprintf('\nBursts con presión media problemática: %d\n', sum(pressure_flag));

fprintf('Bursts con porcentaje excesivo de muestras inválidas o bajas: %d\n', sum(pressure_sample_flag));

%% Guardar metadatos seleccionados

data.instrument_type = "RBR";
data.hdr = struct();

% Información general calculada a partir del archivo de bursts.
general = struct();

general.Number_of_wave_measurements = nBursts;
general.Number_of_samples = nRows;

general.Time_of_first_measurement = ...
    burst_start_time(1);

general.Time_of_last_measurement = ...
    burst_end_time(end);

general.Deployment_duration = ...
    general.Time_of_last_measurement - ...
    general.Time_of_first_measurement;

general.First_burst_counter = burst_ids(1);
general.Last_burst_counter = burst_ids(end);

general.Expected_number_of_wave_measurements = ...
    burst_ids(end) - burst_ids(1) + 1;

general.Number_of_missing_wave_measurements = ...
    general.Expected_number_of_wave_measurements - nBursts;

data.hdr.general = general;

% Configuración de muestreo necesaria para escritura y procesamiento.
setup = struct();

setup.Sampling_mode = ...
    string(get_field_default(metadata.sampling, 'mode', "WAVE"));

setup.Wave_Interval_s = burst_interval_s;
setup.Wave_Number_of_samples = expected_nSamples;
setup.Wave_Sampling_interval_s = sampling_interval_s;
setup.Wave_Sampling_rate_Hz = sampling_rate_Hz;
setup.Wave_burst_duration_s = burst_duration_s;
setup.Wave_Nyquist_frequency_Hz = sampling_rate_Hz / 2;

setup.Wave_frequency_resolution_Hz = ...
    sampling_rate_Hz / expected_nSamples;

setup.Pressure_units = pressure_units;

% Campos no aplicables al RBR, conservados para facilitar la interfaz
% estándar con wsa_nc_write.
setup.Coordinate_system = "not applicable";
setup.Blanking_distance_m = NaN;

if isfield(metadata, 'parameters') && ...
        isstruct(metadata.parameters)

    setup.Time_offset_from_UTC_hours = ...
        get_numeric_field( ...
            metadata.parameters, ...
            'offsetfromutc', ...
            NaN);

    setup.Atmospheric_pressure_dbar = ...
        get_numeric_field( ...
            metadata.parameters, ...
            'atmpressure', ...
            NaN);

    setup.Density = ...
        get_numeric_field( ...
            metadata.parameters, ...
            'density', ...
            NaN);

    setup.Salinity = ...
        get_numeric_field( ...
            metadata.parameters, ...
            'salinity', ...
            NaN);

else
    setup.Time_offset_from_UTC_hours = NaN;
    setup.Atmospheric_pressure_dbar = NaN;
    setup.Density = NaN;
    setup.Salinity = NaN;
end

data.hdr.setup = setup;

% Información del instrumento.
hardware = struct();

hardware.Serial_number = ...
    string(get_field_default( ...
        metadata.instrument, ...
        'serial', ...
        ""));

hardware.Model = ...
    string(get_field_default( ...
        metadata.instrument, ...
        'model', ...
        ""));

hardware.Firmware_type = ...
    get_numeric_field( ...
        metadata.instrument, ...
        'fwtype', ...
        NaN);

hardware.Firmware_version = ...
    get_numeric_field( ...
        metadata.instrument, ...
        'fwversion', ...
        NaN);

if isfield(metadata, 'version') && ...
        isstruct(metadata.version)

    hardware.Ruskin_version = ...
        string(get_field_default( ...
            metadata.version, ...
            'ruskin', ...
            ""));

    hardware.Metadata_file_version = ...
        string(get_field_default( ...
            metadata.version, ...
            'file', ...
            ""));

else
    hardware.Ruskin_version = "";
    hardware.Metadata_file_version = "";
end

data.hdr.hardware_configuration = hardware;

% El RBR no posee un cabezal acústico ni matriz de transformación.
head_configuration = struct();

head_configuration.Serial_number = "";
head_configuration.Pressure_sensor = "yes";
head_configuration.Transformation_matrix = [];

head_configuration.Pressure_sensor_calibration = ...
    find_channel_calibration( ...
        metadata, ...
        'dataheader', ...
        'Pressure');

data.hdr.head_configuration = head_configuration;

% Información de trazabilidad de la exportación.
ruskin_export = struct();

ruskin_export.Deployment_name = deployment_name;
ruskin_export.Export_time = NaT;
ruskin_export.Export_start_time = NaT;
ruskin_export.Export_end_time = NaT;
ruskin_export.Schedule_start_time = NaT;
ruskin_export.Schedule_end_time = NaT;

if isfield(metadata, 'export') && ...
        isstruct(metadata.export)

    ruskin_export.Export_time = ...
        parse_metadata_datetime( ...
            get_field_default( ...
                metadata.export, ...
                'exporttime', ...
                ""));

    ruskin_export.Export_start_time = ...
        parse_metadata_datetime( ...
            get_field_default( ...
                metadata.export, ...
                'starttime', ...
                ""));

    ruskin_export.Export_end_time = ...
        parse_metadata_datetime( ...
            get_field_default( ...
                metadata.export, ...
                'endtime', ...
                ""));
end

if isfield(metadata, 'schedule') && ...
        isstruct(metadata.schedule)

    ruskin_export.Schedule_start_time = ...
        parse_metadata_datetime( ...
            get_field_default( ...
                metadata.schedule, ...
                'starttime', ...
                ""));

    ruskin_export.Schedule_end_time = ...
        parse_metadata_datetime( ...
            get_field_default( ...
                metadata.schedule, ...
                'endtime', ...
                ""));
end

data.hdr.ruskin_export = ruskin_export;

data.hdr.file_paths = struct();
data.hdr.file_paths.metadata = file_metadata;
data.hdr.file_paths.burst = file_burst;
data.hdr.burst_segmentation_method = "Burst column";

%% Control de calidad

empty_flags = struct( ...
    'samples_flag', false, ...
    'pressure_flag', false, ...
    'pressure_sample_flag', false);

data.quality.flags = ...
    repmat(empty_flags, nBursts, 1);

for b = 1:nBursts
    data.quality.flags(b).samples_flag = samples_flag(b);

    data.quality.flags(b).pressure_flag = pressure_flag(b);
    
    data.quality.flags(b).pressure_sample_flag = pressure_sample_flag(b);
end

bad_bursts = samples_flag | pressure_flag | pressure_sample_flag;

qc_summary = struct();

qc_summary.total_bursts = nBursts;

qc_summary.samples_flag_count = sum(samples_flag);
qc_summary.pressure_flag_count = sum(pressure_flag);
qc_summary.pressure_sample_flag_count = sum(pressure_sample_flag);

qc_summary.bad_bursts = bad_bursts;
qc_summary.total_bad_bursts = sum(bad_bursts);
qc_summary.total_good_bursts = sum(~bad_bursts);

qc_summary.percentage_bad = 100*sum(bad_bursts)/nBursts;

qc_summary.bad_indices = find(bad_bursts);
qc_summary.good_indices = find(~bad_bursts);

qc_summary.time_start = burst_start_time(1);
qc_summary.time_end = burst_end_time(end);

qc_summary.actual_samples = actual_samples;
qc_summary.expected_samples = expected_nSamples;

qc_summary.time_interval_flag = time_interval_flag;

qc_summary.bad_pressure_sample_percentage = bad_pressure_sample_percentage;

qc_summary.median_pressure_dbar = median_pressure;

qc_summary.burst_time_mismatch_count = sum(burst_time_mismatch);

if any(bad_bursts)
    qc_summary.bad_datetimes = burst_start_time(bad_bursts);

else
    qc_summary.bad_datetimes = datetime.empty(0,1);
end

data.quality.summary = qc_summary;

data.cleaning_status = false;
data.preprocessing_status = false;

%% Figuras opcionales

if do_plot

    create_rbr_qc_plots( ...
        mean_pressure, ...
        median_pressure, ...
        pressure_flag, ...
        bad_pressure_sample_percentage, ...
        pressure_sample_flag, ...
        min_pressure_limit_abs, ...
        pressure_drop_limit, ...
        bad_pressure_sample_percentage_limit, ...
        save_plot_dir);
end

%% Resumen final

fprintf('\n----------------------------          Resumen de verificaciones          ----------------------------\n');

fprintf('\nTotal de bursts problemáticos: %d de %d (%.2f %%).\n', ...
    qc_summary.total_bad_bursts, ...
    nBursts, ...
    qc_summary.percentage_bad);

fprintf('\nLectura de RBR finalizada correctamente.\n');

fprintf('\n========================================================================================================================\n');

end


%% Funciones locales

function [file_burst, file_metadata, deployment_name] = locate_rbr_files(files_dir)

files_txt = dir(fullfile(files_dir, '*.txt'));
file_names = string({files_txt.name});

burst_match = endsWith(lower(file_names), "_burst.txt");

metadata_match = endsWith(lower(file_names), "_metadata.txt");

burst_files = files_txt(burst_match);
metadata_files = files_txt(metadata_match);

if isempty(burst_files)

    error('No se encontró ningún archivo *_burst.txt en: %s', ...
        files_dir);

elseif numel(burst_files) > 1

    error('Se encontraron varios archivos *_burst.txt:\n%s', ...
        strjoin(string({burst_files.name}), newline));
end

if isempty(metadata_files)

    error('No se encontró ningún archivo *_metadata.txt en: %s', ...
        files_dir);

elseif numel(metadata_files) > 1

    error('Se encontraron varios archivos *_metadata.txt:\n%s', ...
        strjoin(string({metadata_files.name}), newline));
end

burst_name = string(burst_files.name);
metadata_name = string(metadata_files.name);

burst_stem = extractBefore( ...
    burst_name, ...
    strlength(burst_name) - ...
    strlength("_burst.txt") + 1);

metadata_stem = extractBefore( ...
    metadata_name, ...
    strlength(metadata_name) - ...
    strlength("_metadata.txt") + 1);

if ~strcmpi(burst_stem, metadata_stem)

    error(['Los archivos de burst y metadatos no comparten el ' ...
           'mismo nombre base:\n  %s\n  %s'], ...
           burst_name, ...
           metadata_name);
end

deployment_name = burst_stem;

file_burst = ...
    fullfile(files_dir, char(burst_name));

file_metadata = ...
    fullfile(files_dir, char(metadata_name));

end


function [time, burst_counter, pressure] = read_rbr_burst_file(filename)

fid = fopen(filename, 'r');

if fid < 0
    error('No fue posible abrir el archivo: %s', filename);
end

cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

header_line = fgetl(fid);

if ~ischar(header_line)
    error('El archivo está vacío: %s', filename);
end

header_line = erase(string(header_line), char(65279));
header = strtrim(split(header_line, ','));

required_header = ["Time", "Burst", "Pressure"];

if numel(header) < 3 || ...
        ~all(strcmpi(header(1:3), required_header'))

    error(['El archivo *_burst.txt debe iniciar con las columnas ' ...
           'Time,Burst,Pressure. Encabezado encontrado:\n%s'], ...
           strjoin(header, ','));
end

% Ruskin puede agregar columnas derivadas, por ejemplo Wave. Se omiten sin
% almacenarlas. El formato %q permite ignorar campos numéricos o de texto.
format_spec = '%{yyyy-MM-dd HH:mm:ss.SSS}D%f%f';

for k = 4:numel(header)
    format_spec = [format_spec, '%*q']; %#ok<AGROW>
end

try

    values = textscan( ...
        fid, ...
        format_spec, ...
        'Delimiter', ',', ...
        'ReturnOnError', false, ...
        'TreatAsEmpty', {'NaN', 'nan', 'NA'});

catch ME

    error('No fue posible interpretar el archivo de bursts:\n%s\n%s', ...
        filename, ...
        ME.message);
end

if numel(values) < 3
    error('No fue posible extraer las columnas Time, Burst y Pressure.');
end

time = values{1};
burst_counter = double(values{2});
pressure = double(values{3});

end


function value = get_field_default(s, field_name, default_value)

if isstruct(s) && isfield(s, field_name)

    value = s.(field_name);

    if isempty(value)
        value = default_value;
    end

else
    value = default_value;
end

end


function value = get_numeric_field(s, field_name, default_value)

raw_value = get_field_default(s, field_name, default_value);

if isnumeric(raw_value) || islogical(raw_value)

    if isscalar(raw_value)
        value = double(raw_value);
    else
        value = default_value;
    end

else

    value = str2double(string(raw_value));

    if ~isscalar(value) || ~isfinite(value)
        value = default_value;
    end
end

end


function units = find_channel_units(metadata, header_field, channel_name)

units = "";

if ~isfield(metadata, header_field)
    return
end

header = metadata.(header_field);

for k = 1:numel(header)

    if iscell(header)
        item = header{k};
    else
        item = header(k);
    end

    if isstruct(item) && isfield(item, 'name') && strcmpi(string(item.name), string(channel_name))
        if isfield(item, 'units') && ~isempty(item.units)
            units = string(item.units);
        end
        return
    end
end

end


function calibration = find_channel_calibration(metadata, header_field, channel_name)

calibration = struct();

if ~isfield(metadata, header_field)
    return
end

header = metadata.(header_field);

for k = 1:numel(header)

    if iscell(header)
        item = header{k};
    else
        item = header(k);
    end

    if isstruct(item) && isfield(item, 'name') && strcmpi(string(item.name), string(channel_name))
        if isfield(item, 'calibration') && isstruct(item.calibration)
            calibration = item.calibration;
        end

        return
    end
end

end


function value = parse_metadata_datetime(raw_value)

value = NaT;
raw_value = string(raw_value);

if ismissing(raw_value) || ...
        strlength(strtrim(raw_value)) == 0

    return
end

try

    value = datetime(raw_value, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');

catch
    value = NaT;
end

end


function create_rbr_qc_plots( ...
    mean_pressure, ...
    median_pressure, ...
    pressure_flag, ...
    bad_pressure_sample_percentage, ...
    pressure_sample_flag, ...
    min_pressure_limit_abs, ...
    pressure_drop_limit, ...
    bad_pressure_sample_percentage_limit, ...
    save_plot_dir)

burst_index = (1:numel(mean_pressure))';

%% Presión media

f1 = figure('Name', 'Verificación de presión', 'Color', 'w');

f1.Position = [1, 1, 1900, 1000];

hold on

plot(burst_index, mean_pressure, '-', 'DisplayName', 'Presión media', 'LineWidth', 1.5);

yline(min_pressure_limit_abs, '--', 'DisplayName', 'Presión mínima');
yline(median_pressure, '-', 'DisplayName', 'Mediana');
yline(median_pressure + pressure_drop_limit, ':', 'DisplayName', 'Mediana + límite');
yline(median_pressure - pressure_drop_limit, ':','DisplayName', 'Mediana - límite');

if any(pressure_flag)
    scatter(burst_index(pressure_flag), mean_pressure(pressure_flag), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
end

hold off

title('Verificación de presión media absoluta por burst');
xlabel('Burst');
ylabel('Presión media absoluta (dbar)');
legend('Location', 'best');
grid on
box on

%% Porcentaje de muestras problemáticas

f2 = figure('Name', 'Verificación de muestras de presión', 'Color', 'w');

f2.Position = [1, 1, 1900, 1000];

hold on

plot(burst_index, bad_pressure_sample_percentage, '-', 'DisplayName', 'Porcentaje superior al límite', 'LineWidth', 1.5);

yline(bad_pressure_sample_percentage_limit, '--', 'DisplayName', 'Porcentaje máximo');

if any(pressure_sample_flag)
    scatter(burst_index(pressure_sample_flag), bad_pressure_sample_percentage(pressure_sample_flag), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
end

hold off

title(['Verificación de muestras de presión: ' 'porcentaje superior límite']);
xlabel('Burst');
ylabel('Porcentaje (%)');
legend('Location', 'best');
grid on
box on

%% Guardar figuras

if ~isempty(save_plot_dir)

    exportgraphics( ...
        f1, ...
        fullfile( ...
            save_plot_dir, ...
            'verificacion_presion.png'), ...
        'Resolution', ...
        300);

    exportgraphics( ...
        f2, ...
        fullfile( ...
            save_plot_dir, ...
            'verificacion_presion_muestras.png'), ...
        'Resolution', ...
        300);
end

end