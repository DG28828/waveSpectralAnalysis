function data = wsa_awac_read(files_dir, varargin)
%wsa_read_awac - Importa datos de AWAC.
%
%   AAAA
%
%
%
%   Sintaxis:
%       data = wsa_read_awac(files_dir, varargin)
%
%
%   Argumentos de entrada (requeridos):
%
%
%
%   Parámetros Nombre-Valor (opcionales):
%
%
%
%   Argumentos de salida:
%
%
%
%   Notas:
%   • 
%
%   • 
%
%   • 
%
%   • 
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/03/2026
% Fecha de modificación: 10/03/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
pitch_limit_default = 10;           % grados
roll_limit_default  = 10;           % grados
heading_jump_limit_default = 20;    % cambio brusco entre bursts
tilt_jump_limit_default    = 5;     % cambio brusco pitch/roll
min_pressure_limit_default = 1;             % dbar (casi fuera del agua)
pressure_drop_limit_default = 5;            % dbar respecto a mediana

%Input parser
p = inputParser;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'files_dir');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%
addParameter(p, 'pitch_limit', pitch_limit_default)
addParameter(p, 'roll_limit', roll_limit_default)
addParameter(p, 'heading_jump_limit', heading_jump_limit_default)
addParameter(p, 'tilt_jump_limit', tilt_jump_limit_default)
addParameter(p, 'min_pressure_limit', min_pressure_limit_default)
addParameter(p, 'pressure_drop_limit', pressure_drop_limit_default)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, files_dir, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
pitch_limit = p.Results.pitch_limit;        
roll_limit  = p.Results.roll_limit;         
heading_jump_limit = p.Results.heading_jump_limit;    
tilt_jump_limit    = p.Results.tilt_jump_limit;
min_pressure_limit = p.Results.min_pressure_limit;
pressure_drop_limit  = p.Results.pressure_drop_limit;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales


% Verificar que filename sea string o char
if ~(ischar(files_dir) || isstring(files_dir))
    error('El argumento de entrada "filename" debe ser un string o char.');
end
files_dir = char(files_dir);  % Asegurar tipo char

% Verificar que la carpeta exista
if ~isfolder(files_dir)
    error('La carpeta no existe: %s', files_dir);
end

% Buscar archivos requeridos
hdr_files = dir(fullfile(files_dir, '*.hdr'));
whd_files = dir(fullfile(files_dir, '*.whd'));
wad_files = dir(fullfile(files_dir, '*.wad'));

% Verificar que exista exactamente un archivo .hdr
if isempty(hdr_files)
    error('No se encontró ningún archivo .hdr en la carpeta: %s', files_dir);
elseif numel(hdr_files) > 1
    error('Se encontró más de un archivo .hdr en la carpeta: %s', files_dir);
end

% Verificar que exista exactamente un archivo .whd
if isempty(whd_files)
    error('No se encontró ningún archivo .whd en la carpeta: %s', files_dir);
elseif numel(whd_files) > 1
    error('Se encontró más de un archivo .whd en la carpeta: %s', files_dir);
end

% Verificar que exista exactamente un archivo .wad
if isempty(wad_files)
    error('No se encontró ningún archivo .wad en la carpeta: %s', files_dir);
elseif numel(wad_files) > 1
    error('Se encontró más de un archivo .wad en la carpeta: %s', files_dir);
end

% Construir rutas completas
file_hdr = fullfile(hdr_files(1).folder, hdr_files(1).name);
file_whd = fullfile(whd_files(1).folder, whd_files(1).name);
file_wad = fullfile(wad_files(1).folder, wad_files(1).name);

fprintf('\nExtrayendo información de archivos .hdr, .whd y .wad.\n')

%% Inicializar struct principal
data = struct();
data.general_info = struct();

%% Leer el archivo .hdr

hdr_txt = fileread(file_hdr);

% Información general
general = struct();

general.Number_of_measurements = str2double( ...
    regexp(hdr_txt, 'Number of measurements\s+(\d+)', 'tokens', 'once'));

general.Time_of_first_measurement = datetime( ...
    regexp(hdr_txt, 'Time of first measurement\s+([0-9/: ]+)', 'tokens', 'once'), ...
    'InputFormat','dd/MM/yyyy HH:mm:ss');

general.Time_of_last_measurement = datetime( ...
    regexp(hdr_txt, 'Time of last measurement\s+([0-9/: ]+)', 'tokens', 'once'), ...
    'InputFormat','dd/MM/yyyy HH:mm:ss');

%Información de Setup
setup = struct();

setup.Compass_update_rate = str2double( ...
    regexp(hdr_txt, 'Compass update rate\s+(\d+)', 'tokens', 'once') );

setup.Wave_measurements = string( ...
    regexp(hdr_txt, 'Wave measurements\s+(\w+)', 'tokens', 'once'));

setup.Wave_Number_of_samples = str2double( ...
    regexp(hdr_txt, 'Wave - Number of samples\s+(\d+)', 'tokens', 'once'));

setup.Wave_Sampling_rate = str2double( ...
    regexp(hdr_txt, 'Wave - Sampling rate\s+(\d+)', 'tokens', 'once'));

setup.Coordinate_system = string( ...
    regexp(hdr_txt, 'Coordinate system\s+(\w+)', 'tokens', 'once'));

setup.Sound_speed = string( ...
    regexp(hdr_txt, 'Sound speed\s+(\w+)', 'tokens', 'once'));

setup.Number_of_beams = str2double( ...
    regexp(hdr_txt, 'Number of beams\s+(\d+)', 'tokens', 'once'));

setup.Deployment_time = datetime( ...
    regexp(hdr_txt, 'Deployment time\s+([0-9/: ]+)', 'tokens', 'once'), ...
    'InputFormat','dd/MM/yyyy HH:mm:ss');

% Información del head
head_config = struct();

% Extraer únicamente el bloque Head configuration
head_block = regexp(hdr_txt, ...
    'Head configuration\s*-+\s*(.*?)\s*Current profile cell center distance', ...
    'tokens','once');

head_block = head_block{1};

head_config.Pressure_sensor = string( ...
    regexp(head_block, 'Pressure sensor\s+(\w+)', 'tokens','once'));

head_config.Compass = string( ...
    regexp(head_block, '^\s*Compass\s+(\w+)', 'tokens','once','lineanchors'));

head_config.Tilt_sensor = string( ...
    regexp(head_block, 'Tilt sensor\s+(\w+)', 'tokens','once'));

head_config.Number_of_beams = str2double( ...
    regexp(head_block, 'Number of beams\s+(\d+)', 'tokens','once'));

tm = regexp(hdr_txt, ...
    'Transformation matrix\s+([-\d\. ]+)\s+([-\d\. ]+)\s+([-\d\. ]+)', ...
    'tokens','once');
head_config.Transformation_matrix = str2num( ...
    char(join(string(tm),' ')) );
head_config.Transformation_matrix = reshape(head_config.Transformation_matrix,3,3)';

mm = regexp(hdr_txt, ...
    'Magnetometer calibration matrix\s+([-\d\. ]+)\s+([-\d\. ]+)\s+([-\d\. ]+)', ...
    'tokens','once');
head_config.Magnetometer_calibration_matrix = str2num( ...
    char(join(string(mm),' ')) );
head_config.Magnetometer_calibration_matrix = reshape(head_config.Magnetometer_calibration_matrix,3,3)';

chi = regexp(hdr_txt, ...
    'Compass hard iron calibration\s+([-\d ]+)', ...
    'tokens','once');
head_config.Compass_hard_iron_calibration = str2num(chi{1});

psc = regexp(hdr_txt, ...
    'Pressure sensor calibration\s+([-\d ]+)', ...
    'tokens','once');
head_config.Pressure_sensor_calibration = str2num(psc{1});

% Guardar información en struct principal
data.general_info.general = general;
data.general_info.setup   = setup;
data.general_info.head_configuration = head_config;

fprintf('\tInformación de archivo .hdr extraida correctamente.\n')


%% Leer el archivo .whd

whd = load(file_whd);

% Verificación
if size(whd,2) ~= 25
    error('El archivo .whd no tiene 25 columnas como se esperaba.');
end


N = size(whd,1);
wave_info(N,1) = struct();

for i = 1:N

    wave_info(i).datetime = datetime( ...
        whd(i,3), ... % Year
        whd(i,1), ... % Month
        whd(i,2), ... % Day
        whd(i,4), ... % Hour
        whd(i,5), ... % Minute
        whd(i,6));    % Second

    wave_info(i).burst_counter       = whd(i,7);
    wave_info(i).n_wave_records      = whd(i,8);
    wave_info(i).cell_position_m     = whd(i,9);
    wave_info(i).battery_voltage_V   = whd(i,10);
    wave_info(i).sound_speed_ms      = whd(i,11);
    wave_info(i).heading_deg         = whd(i,12);
    wave_info(i).pitch_deg           = whd(i,13);
    wave_info(i).roll_deg            = whd(i,14);
    wave_info(i).min_pressure_dbar   = whd(i,15);
    wave_info(i).max_pressure_dbar   = whd(i,16);
    wave_info(i).temperature_degC    = whd(i,17);
    wave_info(i).cell_size_m         = whd(i,18);

    wave_info(i).noise_amp_beams = whd(i,19:22);

    wave_info(i).ast_window_start_m  = whd(i,23);
    wave_info(i).ast_window_size_m   = whd(i,24);
    wave_info(i).ast_window_offset_m = whd(i,25);

end

data.wave_info = wave_info;
nBursts = size(wave_info, 1);

fprintf('\tInformación de archivo .whd extraida correctamente.\n')

%% Leer el archivo .wad

wad = load(file_wad);

if size(wad,2) ~= 17
    error('El archivo .wad no tiene 17 columnas como se esperaba.');
end

%Crear vector de fechas.
time = datetime( ...
    wad(:,3), ... % Year
    wad(:,1), ... % Month
    wad(:,2), ... % Day
    wad(:,4), ... % Hour
    wad(:,5), ... % Minute
    wad(:,6));    % Second

%Identificar inicios y finales de cada burst basado en las mediciones de
%tiempo (fecha y hora)
dt = seconds(diff(time));

threshold = 5;   % segundos (ajustable si necesario)
burst_breaks = find(dt > threshold);

burst_start = [1; burst_breaks + 1];        %Índices de inicio
burst_end   = [burst_breaks; length(time)]; %Índices de final



%Struct con los bursts
nBursts_wad_detected = length(burst_start);
wave_data(nBursts_wad_detected,1) = struct();

for b = 1:nBursts_wad_detected

    idx = burst_start(b):burst_end(b);

    wave_data(b).datetime = time(idx);
    wave_data(b).pressure_dbar = wad(idx,7);

    wave_data(b).ast_distance_m = wad(idx,8:9);
    wave_data(b).ast_quality    = wad(idx,10);

    wave_data(b).analog_input   = wad(idx,11);

    wave_data(b).velocity_ms = wad(idx,12:14);
    wave_data(b).amplitude   = wad(idx,15:17);

    wave_data(b).nSamples = length(idx);

end

data.wave_data = wave_data;

fprintf('\tInformación de archivo .wad extraida correctamente.\n')

%% Verificación de calidad de los datos #1
%
% Verificaciones realizadas:
%   -Cantidad de bursts deben coincidir en .whd y .wad.
%   -Número de muestras de cada burst en .wad debe coincidir con el número
%    de muestras por burst indicados en .whd.

fprintf('\nComenzando verificación de calidad de los datos: tamaños\n')

% Verificación de cantidad de bursts.
fprintf('\tVerificando consistencia en cantidad de bursts...\n')
nBursts_whd = length(data.wave_info);
nBursts_wad = length(data.wave_data);
burst_mismatch = false;
if nBursts_whd ~= nBursts_wad
    fprintf('\t\tNúmero de bursts distinto entre .whd (%d) y .wad (%d).\n', ...
        nBursts_whd, nBursts_wad);
    burst_mismatch = true;
end
if ~burst_mismatch
    fprintf('\t\tVerificación de bursts OK: la cantidad de bursts entre .whd y .wad coincide.\n');
end

% Verificación de número de muestras por burst.
fprintf('\tVerificando consistencia en cantidad de muestras por burst...\n')
minBursts = min(nBursts_whd, nBursts_wad);
size_flag = false(nBursts,1);
mismatch = false;
for b = 1:minBursts
    expected = data.wave_info(b).n_wave_records;
    actual   = data.wave_data(b).nSamples;
    if expected ~= actual
        fprintf('\t\tBurst %d: esperado %d muestras, encontrado %d.\n', ...
            b, expected, actual);
        size_flag(b) = true;
        mismatch = true;
    end
end
if ~mismatch
    fprintf('\t\tVerificación de muestras OK: la cantidad de muestras de todos los bursts de .wad coincide con la esperada en .whd.\n');
end
for b = 1:nBursts
    data.quality_control.flags(b).size_flag = size_flag(b);
end

% Verificación temporal
fprintf('\tVerificando existencia de desplazamientos temporales en bursts...\n')
time_mismatch = false;
for b = 1:minBursts
    t_whd = data.wave_info(b).datetime;
    t_wad = data.wave_data(b).datetime(1);
    dt_seconds = abs(seconds(t_wad - t_whd));
    if dt_seconds > 1   % tolerancia de 1 segundo
        fprintf(['\t\tBurst %d: diferencia temporal entre .whd y .wad = %.2f s ' ...
                 '(whd: %s | wad: %s)\n'], ...
                 b, dt_seconds, string(t_whd), string(t_wad));
        time_mismatch = true;
    end 
end
if ~time_mismatch
    fprintf('\t\tVerificación temporal OK: todos los bursts están alineados.\n');
end



%% Verificación de calidad de los datos #2
%
% Verificaciones realizadas:

fprintf('\nComenzando verificación de calidad de los datos: orientación.\n')

quality_control = struct();

fprintf('\tLímites establecidos:\n')
fprintf('\t\t-Pitch máximo: %d °\n', pitch_limit)
fprintf('\t\t-Roll máximo: %d °\n', roll_limit)
fprintf('\t\t-Cambio máximo en heading: %d °\n', heading_jump_limit)
fprintf('\t\t-Cambio máximo en tilt (pitch/roll): %d °\n', tilt_jump_limit)



heading = [data.wave_info.heading_deg];
pitch   = [data.wave_info.pitch_deg];
roll    = [data.wave_info.roll_deg];


orientation_flag = false(nBursts,1);

% 1) Límites absolutos
bad_tilt = abs(pitch) > pitch_limit | abs(roll) > roll_limit;

% 2) Cambios bruscos entre bursts
d_heading = abs(diff(heading));
d_pitch   = abs(diff(pitch));
d_roll    = abs(diff(roll));

% Corregir wrapping de heading (0–360)
d_heading = min(d_heading, 360 - d_heading);

bad_jump = [false, ...
    d_heading > heading_jump_limit | ...
    d_pitch   > tilt_jump_limit    | ...
    d_roll    > tilt_jump_limit];

orientation_flag = bad_tilt' | bad_jump';

% Guardar flags
for b = 1:nBursts
    data.quality_control.flags(b).orientation_flag = orientation_flag(b);
    if orientation_flag(b)
        fprintf('\tBurst %d presenta problemas de orientación\n', b)
    end
end

fprintf('\tResumen: %d bursts marcados como sospechosos.\n', ...
    sum(orientation_flag));




fprintf('\nComenzando verificación de calidad de los datos: presión.\n')

mean_pressure = zeros(nBursts,1);

for b = 1:nBursts
    mean_pressure(b) = mean(data.wave_data(b).pressure_dbar);
end

median_pressure = median(mean_pressure);

fprintf('\tLímites establecidos:\n')
fprintf('\t\t-Presión mínima: %d dbar\n', min_pressure_limit)
fprintf('\t\t-Diferencia de presión respecto a la mediana: %d dbar\n', pressure_drop_limit)

bad_pressure = mean_pressure < min_pressure_limit | ...
               abs(mean_pressure - median_pressure) > pressure_drop_limit;

for b = 1:nBursts
    data.quality_control.flags(b).pressure_flag = bad_pressure(b);
    if bad_pressure(b)
        fprintf('\tBurst %d presenta problemas de presión\n', b)
    end
end

fprintf('\tResumen: %d bursts marcados como sospechosos.\n', ...
    sum(bad_pressure));

%% Resumen
fprintf('\nResumen de control de calidad de los datos:\n')

size_flag        = [data.quality_control.flags.size_flag]';
orientation_flag = [data.quality_control.flags.orientation_flag]';
pressure_flag    = [data.quality_control.flags.pressure_flag]';

bad_bursts = size_flag | orientation_flag | pressure_flag;

fprintf('\tTotal bursts malos detectados: %d de %d\n', ...
    sum(bad_bursts), length(bad_bursts));



qc_summary = struct();

qc_summary.total_bursts = nBursts;

qc_summary.size_flag_count        = sum(size_flag);
qc_summary.orientation_flag_count = sum(orientation_flag);
qc_summary.pressure_flag_count    = sum(pressure_flag);

qc_summary.bad_bursts = bad_bursts;
qc_summary.total_bad_bursts = sum(bad_bursts);
qc_summary.total_good_bursts = sum(~bad_bursts);

qc_summary.percentage_bad = ...
    100 * qc_summary.total_bad_bursts / qc_summary.total_bursts;

qc_summary.bad_indices  = find(bad_bursts);
qc_summary.good_indices = find(~bad_bursts);

% Rango temporal total
qc_summary.time_start = data.wave_info(1).datetime;
qc_summary.time_end   = data.wave_info(end).datetime;

% Rango temporal de bursts malos (si existen)
if any(bad_bursts)
    qc_summary.bad_datetimes = ...
        [data.wave_info(bad_bursts).datetime];
else
    qc_summary.bad_time_start = [];
    qc_summary.bad_time_end   = [];
end

% Guardar en struct principal
data.quality_control.summary = qc_summary;

data.cleaning_applied = false;

end

