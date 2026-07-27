function data = wsa_aquadopp_read(files_dir, varargin)
%wsa_aquadopp_read - lectura y verificación de calidad de datos AQUADOPP.
%
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 22/07/2026
% Fecha de modificación: 27/07/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
%pitch_limit_default         = 10;    % grados
%roll_limit_default          = 10;    % grados
tilt_limit_default          = 30;    %grados (Límite máximo del manual)
heading_jump_limit_default  = 20;    % cambio brusco entre bursts
tilt_jump_limit_default     = 5;    % cambio brusco pitch/roll
min_pressure_limit_default  = 1;     % dbar (casi fuera del agua)
pressure_drop_limit_default = 5;     % dbar respecto a mediana
bad_pressure_sample_percentage_limit_default = 5;  % Porcentaje de samples menores a min_pressure_limit.
plot_default                = false; % No graficar por defecto
save_plot_dir_default       = [];    % Vacio por defecto

%Input parser
p = inputParser;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'files_dir');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%
%addParameter(p, 'pitch_limit', pitch_limit_default)
%addParameter(p, 'roll_limit', roll_limit_default)
addParameter(p, 'tilt_limit', tilt_limit_default)
addParameter(p, 'heading_jump_limit', heading_jump_limit_default)
addParameter(p, 'tilt_jump_limit', tilt_jump_limit_default)
addParameter(p, 'min_pressure_limit', min_pressure_limit_default)
addParameter(p, 'pressure_drop_limit', pressure_drop_limit_default)
addParameter(p, 'bad_pressure_sample_percentage_limit', bad_pressure_sample_percentage_limit_default)
addParameter(p, 'do_plot', plot_default)
addParameter(p, 'save_plot_dir', save_plot_dir_default)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, files_dir, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
%pitch_limit         = p.Results.pitch_limit;        
%roll_limit          = p.Results.roll_limit;   
tilt_limit          = p.Results.tilt_limit; 
heading_jump_limit  = p.Results.heading_jump_limit;    
tilt_jump_limit     = p.Results.tilt_jump_limit;
min_pressure_limit  = p.Results.min_pressure_limit;
pressure_drop_limit = p.Results.pressure_drop_limit;
bad_pressure_sample_percentage_limit = p.Results.bad_pressure_sample_percentage_limit;
do_plot             = p.Results.do_plot;
save_plot_dir       = p.Results.save_plot_dir;  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('===========================================          Lectura de AQUADOPP         ===========================================\n');
fprintf('\nLeer datos de archivos crudos de AQUADOPP.\n');

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
dat_files = dir(fullfile(files_dir, '*.dat'));
dia_files = dir(fullfile(files_dir, '*.dia'));

% Verificar que exista exactamente un archivo .hdr
if isempty(hdr_files)
    error('No se encontró ningún archivo .hdr en la carpeta: %s', files_dir);
elseif numel(hdr_files) > 1
    error('Se encontró más de un archivo .hdr en la carpeta: %s', files_dir);
end

% Verificar que exista exactamente un archivo .dat
if isempty(dat_files)
    error('No se encontró ningún archivo .dat en la carpeta: %s', files_dir);
elseif numel(dat_files) > 1
    error('Se encontró más de un archivo .dat en la carpeta: %s', files_dir);
end

% Verificar que exista exactamente un archivo .dia
if isempty(dia_files)
    error('No se encontró ningún archivo .dia en la carpeta: %s', files_dir);
elseif numel(dia_files) > 1
    error('Se encontró más de un archivo .dia en la carpeta: %s', files_dir);
end

% Construir rutas completas
file_hdr = fullfile(hdr_files(1).folder, hdr_files(1).name);
file_dat = fullfile(dat_files(1).folder, dat_files(1).name);
file_dia = fullfile(dia_files(1).folder, dia_files(1).name);

fprintf('\nDirectorio de los archivos crudos: %s\n', files_dir)

%Si se especifica save_plot_dir automaticamente se hacen las figuras (do_plot = true)
if ~isempty(save_plot_dir)
    do_plot = true;
end

%Carpeta para guardar figuras en caso de requerirse
if do_plot
    if ~isempty(save_plot_dir)
        if ~isfolder(save_plot_dir)
            mkdir(save_plot_dir)
        end
    end
end

%% Inicializar struct principal
data = struct();

%% Leer el archivo .hdr
fprintf('\n-------------------------------          Extrayendo información de archivo .hdr         -------------------------------\n');

data.hdr = struct();

hdr_txt = fileread(file_hdr);

%-------------------------------------------------------------------------%
%----------                Información general                  ----------%
general = struct();
general.Number_of_measurements      = wsa_getNumField(hdr_txt, 'Number of measurements');
general.Number_of_checksum_errors   = wsa_getNumField(hdr_txt, 'Number of checksum errors');
general.Time_of_first_measurement   = wsa_getDateField(hdr_txt, 'Time of first measurement');
general.Time_of_last_measurement    = wsa_getDateField(hdr_txt, 'Time of last measurement');

%Calculado
if ~isnat(general.Time_of_first_measurement) && ~isnat(general.Time_of_last_measurement)
    general.Deployment_duration = general.Time_of_last_measurement - general.Time_of_first_measurement;
else
    general.Deployment_duration = duration.empty;
end
%-------------------------------------------------------------------------%



%-------------------------------------------------------------------------%
%----------                Información de Setup                 ----------%
setup = struct();
setup.Measurement_interval_s      = wsa_getNumField(hdr_txt, 'Measurement interval');   % +
setup.Sampling_mode               = wsa_getStrField(hdr_txt, 'Sampling rate');          % +

setup.Average_interval_s          = wsa_getNumField(hdr_txt, 'Average interval');       % =
setup.Measurement_load_percent    = wsa_getNumField(hdr_txt, 'Measurement load');       % =
setup.Transmit_pulse_length_m     = wsa_getNumField(hdr_txt, 'Transmit pulse length');  % =
setup.Blanking_distance_m         = wsa_getNumField(hdr_txt, 'Blanking distance');      % =
setup.Compass_update_rate_s       = wsa_getNumField(hdr_txt, 'Compass update rate');    % =

setup.Diagnostics_measurements    = wsa_getStrField(hdr_txt, 'Diagnostics measurements');% +
setup.Diagnostics_Interval_s      = wsa_getNumField(hdr_txt, 'Diagnostics - Interval'); % +
setup.Diagnostics_Number_of_samples  = wsa_getNumField(hdr_txt, 'Diagnostics - Number of samples'); % +
setup.Diagnostics_Cell_number     = wsa_getNumField(hdr_txt, 'Diagnostics - Cell number'); % +
setup.Diagnostics_Number_of_pings      = wsa_getNumField(hdr_txt, 'Diagnostics - Number of pings'); % +

setup.Diagnostics_Sampling_rate_Hz = 1; % Aquadopp solo hace muestras a 1 Hz.
setup.Diagnostics_Sampling_interval_s = 1/setup.Diagnostics_Sampling_rate_Hz;
setup.Diagnostics_burst_duration_s = setup.Diagnostics_Number_of_samples/setup.Diagnostics_Sampling_rate_Hz;
setup.Diagnostics_Nyquist_frequency_Hz = setup.Diagnostics_Sampling_rate_Hz/2;
setup.Diagnostics_frequency_resolution_Hz = setup.Diagnostics_Sampling_rate_Hz/setup.Diagnostics_Number_of_samples;

setup.Analog_input_1              = wsa_getStrField(hdr_txt, 'Analog input 1');     % =
setup.External_input_2            = wsa_getStrField(hdr_txt, 'External input 2');   % +
setup.External_input_3            = wsa_getStrField(hdr_txt, 'External input 3');   % +
setup.Power_output                = wsa_getStrField(hdr_txt, 'Power output');       % =
setup.Powerlevel                  = wsa_getStrField(hdr_txt, 'Powerlevel');         % =
setup.Coordinate_system           = wsa_getStrField(hdr_txt, 'Coordinate system');  % =
setup.Salinity_ppt                = wsa_getNumField(hdr_txt, 'Salinity');           % =
setup.Distance_between_pings_m    = wsa_getNumField(hdr_txt, 'Distance between pings');     % =
setup.Number_of_beams             = wsa_getNumField(hdr_txt, 'Number of beams');    % =
setup.Number_of_pings_per_burst   = wsa_getNumField(hdr_txt, 'Number of pings per burst');  % =
setup.Software_version            = wsa_getStrField(hdr_txt, 'Software version');   % =
setup.Deployment_name             = wsa_getStrField(hdr_txt, 'Deployment name');    % =
setup.Wrap_mode                   = wsa_getStrField(hdr_txt, 'Wrap mode');          % =
setup.Deployment_time             = wsa_getDateField(hdr_txt, 'Deployment time');   % =
setup.Comments                    = wsa_getTextField(hdr_txt, 'Comments');          % =
setup.Start_command               = wsa_getTextField(hdr_txt, 'Start command');     % =
setup.CRC_download                = wsa_getStrField(hdr_txt, 'CRC download');       % =


%Calculado
if ~isnat(general.Time_of_first_measurement) && ~isnat(general.Time_of_last_measurement) && isfinite(setup.Diagnostics_Interval_s) && setup.Diagnostics_Interval_s > 0
    total_seconds = seconds( general.Time_of_last_measurement - general.Time_of_first_measurement);
    setup.Expected_number_of_diagnostic_bursts = floor(total_seconds / setup.Diagnostics_Interval_s) + 1;
else
    setup.Expected_number_of_diagnostic_bursts = NaN;
end


if ~isnat(general.Time_of_first_measurement) && ~isnat(general.Time_of_last_measurement) ...
        && ~isnan(setup.Measurement_interval_s) && setup.Measurement_interval_s > 0
    total_seconds = seconds(general.Time_of_last_measurement - general.Time_of_first_measurement);
    setup.Expected_number_of_regular_measurements = floor(total_seconds / setup.Measurement_interval_s) + 1;
else
    setup.Expected_number_of_regular_measurements = NaN;
end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
%----------             Información de Hardware                 ----------%
hardware = struct();

% Extraer bloque
hardware_block = regexp(hdr_txt, ...
    'Hardware configuration\s*-+\s*(.*?)\s*Head configuration', ...
    'tokens', 'once');

if ~isempty(hardware_block)
    hardware_block = hardware_block{1};
else
    hardware_block = '';
end

hardware.Serial_number                    = wsa_getTextField(hardware_block, 'Serial number');
hardware.Hardware_revision                = wsa_getTextField(hardware_block, 'Hardware revision');
hardware.Recorder_size_MByte              = wsa_getNumField(hardware_block, 'Recorder size');
hardware.Firmware_version                 = wsa_getTextField(hardware_block, 'Firmware version');
hardware.Velocity_range                   = wsa_getTextField(hardware_block, 'Velocity range');
hardware.Power_output                     = wsa_getTextField(hardware_block, 'Power output');

% hardware.Analog_input_1_calibration       = wsa_getNumArrayField(hardware_block, 'Analog input #1 calibration \(a0, a1\)');
% hardware.Analog_input_2_calibration       = wsa_getNumArrayField(hardware_block, 'Analog input #2 calibration \(a0, a1\)');

hardware.Sync_signal_data_out_delay_s     = wsa_getNumField(hardware_block, 'Sync signal data out delay');
hardware.Sync_signal_power_down_delay_s   = wsa_getNumField(hardware_block, 'Sync signal power down delay');

hardware.ProLog_ID                        = wsa_getNumField(hardware_block, 'ProLog ID');
hardware.ProLog_firmware_version          = wsa_getTextField(hardware_block, 'ProLog firmware version');

hardware.SD_Card_Inserted                 = wsa_getStrField(hardware_block, 'SD Card Inserted');
hardware.SD_Card_Ready                    = wsa_getStrField(hardware_block, 'SD Card Ready');
hardware.SD_Card_Write_protected          = wsa_getStrField(hardware_block, 'SD Card Write protected');
hardware.SD_Card_Type                     = wsa_getTextField(hardware_block, 'SD Card Type');
hardware.SD_Card_Supported                = wsa_getStrField(hardware_block, 'SD Card Supported');
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
%----------               Información del head                 -----------%
head_config = struct();

% Extraer únicamente el bloque Head configuration
head_block = regexp(hdr_txt, ...
    'Head configuration\s*-+\s*(.*?)\s*Data file format', ...
    'tokens','once');

if ~isempty(head_block)
    head_block = head_block{1};
else
    head_block = '';
end

head_config.Pressure_sensor         = wsa_getStrField(head_block, 'Pressure sensor');
head_config.Compass                 = wsa_getStrField(head_block, 'Compass');
head_config.Tilt_sensor             = wsa_getStrField(head_block, 'Tilt sensor');
head_config.System_1                = wsa_getNumField(head_block, 'System 1');
head_config.Head_frequency_kHz      = wsa_getNumField(head_block, 'Head frequency');
head_config.Serial_number           = wsa_getTextField(head_block, 'Serial number');
head_config.Number_of_beams         = wsa_getNumField(head_block, 'Number of beams');

%Transformation matrix
tm = regexp(hdr_txt, ...
    'Transformation matrix\s+([-\d\. ]+)\s+([-\d\. ]+)\s+([-\d\. ]+)', ...
    'tokens','once');
if ~isempty(tm)
    aux = str2num(char(join(string(tm), ' '))); %#ok<ST2NM>
    head_config.Transformation_matrix = reshape(aux, 3, 3)';
else
    head_config.Transformation_matrix = [];
end

%Magnetometer calibration matrix
mm = regexp(hdr_txt, ...
    'Magnetometer calibration matrix\s+([-\d\. ]+)\s+([-\d\. ]+)\s+([-\d\. ]+)', ...
    'tokens','once');
if ~isempty(mm)
    aux = str2num(char(join(string(mm), ' '))); %#ok<ST2NM>
    head_config.Magnetometer_calibration_matrix = reshape(aux, 3, 3)';
else
    head_config.Magnetometer_calibration_matrix = [];
end

head_config.Compass_hard_iron_calibration = wsa_getNumArrayField(head_block, 'Compass hard iron calibration');
head_config.Pressure_sensor_calibration   = wsa_getNumArrayField(head_block, 'Pressure sensor calibration');
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
%----------       Guardar información en struct principal       ----------%

%Información general del .hdr
data.hdr.general = general;
data.hdr.setup   = setup;
data.hdr.hardware_configuration = hardware;
data.hdr.head_configuration = head_config;

%Formato de archivos .dat y .dia indicado en .hdr
data.hdr.files_format = struct();
data.hdr.files_format.dat = wsa_parse_hdr_data_format(hdr_txt, '.dat');
data.hdr.files_format.dia = wsa_parse_hdr_data_format(hdr_txt, '.dia');
%-------------------------------------------------------------------------%


fprintf('\nInformación de archivo .hdr extraida correctamente.\n')


%-------------------------------------------------------------------------%
%-----------                 Verificaciones                    -----------%

% Verificación de integridad de descarga (checksum)
checksum_errors = data.hdr.general.Number_of_checksum_errors;
fprintf('\nVerificando integridad de descarga (checksum)...\n')
if checksum_errors > 0  
    fprintf(['El archivo .hdr reporta %d errores de checksum. ' ...
             'Esto podría indicar corrupción de datos durante la descarga.\n'], ...
             checksum_errors);
else 
    fprintf('Verificación OK: no se reportan errores de checksum.\n')
end

% Verificación de sistema de coordenadas
coord_system = data.hdr.setup.Coordinate_system;
fprintf('\nVerificando sistema de coordenadas...\n')
if coord_system ~= "ENU" 
    warning(['El sistema de coordenadas del AQUADOPP es "%s". ' ...
             'La función asume coordenadas ENU (East-North-Up). ' ...
             'Los resultados podrían ser incorrectos.'], coord_system);
else  
    fprintf('Sistema de coordenadas OK: ENU.\n')
end
%-------------------------------------------------------------------------%

%% Leer el archivo .dat

fprintf('\n-------------------------------          Extrayendo información de archivo .dat        -------------------------------\n');

dat = load(file_dat);

dat_format = data.hdr.files_format.dat;

% Verificación contra formato definido en .hdr
ncols_dat_expected = data.hdr.files_format.dat.n_columns;
ncols_dat_actual   = size(dat,2);
if ncols_dat_actual ~= ncols_dat_expected
    error(['\nEl archivo .dat tiene %d columnas, pero el .hdr define %d ' ...
           'columnas para este archivo.'], ...
           ncols_dat_actual, ncols_dat_expected);
end


N = size(dat,1);
regular_data(N,1) = struct();

% Índices de columnas .dat según el .hdr
c_dat.month            = wsa_find_column(dat_format, 'Month');
c_dat.day              = wsa_find_column(dat_format, 'Day');
c_dat.year             = wsa_find_column(dat_format, 'Year');
c_dat.hour             = wsa_find_column(dat_format, 'Hour');
c_dat.minute           = wsa_find_column(dat_format, 'Minute');
c_dat.second           = wsa_find_column(dat_format, 'Second');

c_dat.error_code    = wsa_find_column(dat_format, 'Error code'); % +
c_dat.status_code    = wsa_find_column(dat_format, 'Status code'); % +
c_dat.vel1    = wsa_find_column(dat_format, 'Velocity (Beam1'); % +
c_dat.vel2    = wsa_find_column(dat_format, 'Velocity (Beam2'); % +
c_dat.vel3    = wsa_find_column(dat_format, 'Velocity (Beam3'); % +
c_dat.amp1    = wsa_find_column(dat_format, 'Amplitude (Beam1'); % +
c_dat.amp2    = wsa_find_column(dat_format, 'Amplitude (Beam2'); % +
c_dat.amp3    = wsa_find_column(dat_format, 'Amplitude (Beam3'); % +

c_dat.battery_voltage  = wsa_find_column(dat_format, 'Battery voltage');
c_dat.sound_speed      = wsa_find_column(dat_format, 'Soundspeed');
c_dat.heading          = wsa_find_column(dat_format, 'Heading');
c_dat.pitch            = wsa_find_column(dat_format, 'Pitch');
c_dat.roll             = wsa_find_column(dat_format, 'Roll');

c_dat.pressure    = wsa_find_column(dat_format, 'Pressure'); % +

c_dat.temperature      = wsa_find_column(dat_format, 'Temperature');

c_dat.analog1      = wsa_find_column(dat_format, 'Analog input 1'); % +
c_dat.analog2      = wsa_find_column(dat_format, 'Analog input 2'); % +
c_dat.speed      = wsa_find_column(dat_format, 'Speed'); % +
c_dat.direction      = wsa_find_column(dat_format, 'Direction'); % +

for i = 1:N
    regular_data(i).datetime = datetime( ...
        dat(i,c_dat.year), ...
        dat(i,c_dat.month), ...
        dat(i,c_dat.day), ...
        dat(i,c_dat.hour), ...
        dat(i,c_dat.minute), ...
        dat(i,c_dat.second));

    regular_data(i).error_code     = dat(i,c_dat.error_code); % +
    regular_data(i).status_code     = dat(i,c_dat.status_code); % +
    regular_data(i).beam_velocity_ms = [dat(i,c_dat.vel1), dat(i,c_dat.vel2), dat(i,c_dat.vel3)];
    regular_data(i).amplitude = [dat(i,c_dat.amp1), dat(i,c_dat.amp2), dat(i,c_dat.amp3)];

    regular_data(i).battery_voltage_V   = dat(i,c_dat.battery_voltage);
    regular_data(i).sound_speed_ms      = dat(i,c_dat.sound_speed);
    regular_data(i).heading_deg         = dat(i,c_dat.heading);
    regular_data(i).pitch_deg           = dat(i,c_dat.pitch);
    regular_data(i).roll_deg            = dat(i,c_dat.roll);

    regular_data(i).pressure     = dat(i,c_dat.pressure); % +

    regular_data(i).temperature_degC    = dat(i,c_dat.temperature);

    regular_data(i).analog_input = [dat(i,c_dat.analog1), dat(i,c_dat.analog2)];

    regular_data(i).speed     = dat(i,c_dat.speed); % +

    regular_data(i).direction     = dat(i,c_dat.direction); % +

end

data.dat = regular_data;
nMeasurements_dat = numel(data.dat);

fprintf('\nInformación de archivo .dat extraida correctamente.\n')

%%%% Sección eliminada: .dat no registra Wave_number_of_samples
% % Verificación de configuración de muestras de oleaje
% fprintf('\nVerificando consistencia entre configuración de oleaje y .dat...\n')
% 
% expected_samples = data.hdr.setup.Diagnostics_Number_of_samples;
% 
% wave_records = [data.dat.n_wave_records]';
% 
% samples_flag = false(nMeasurements_dat,1);
% 
% mismatch_found = false;
% 
% 
% 
% for b = 1:nMeasurements_dat
% 
%     if wave_records(b) ~= expected_samples
% 
%         fprintf('Burst %d: n_wave_records = %d, esperado = %d\n', ...
%             b, wave_records(b), expected_samples);
% 
%         samples_flag(b) = true;
%         mismatch_found = true;
% 
%     end
% 
% end
% 
% if ~mismatch_found
%     fprintf('Verificación OK: todos los bursts tienen el número esperado de muestras.\n')
% end



%% Leer el archivo .dia

fprintf('\n-------------------------------          Extrayendo información de archivo .dia         -------------------------------\n');

dia = load(file_dia);

dia_format = data.hdr.files_format.dia;

% Verificación contra formato definido en .hdr
ncols_dia_expected = dia_format.n_columns;
ncols_dia_actual   = size(dia,2);
if ncols_dia_actual ~= ncols_dia_expected
    error(['El archivo .dia tiene %d columnas, pero el .hdr define %d columnas ' ...
           'para este archivo.'], ncols_dia_actual, ncols_dia_expected);
end

% Índices de columnas .dia según el .hdr
c_dia.month            = wsa_find_column(dia_format, 'Month');
c_dia.day              = wsa_find_column(dia_format, 'Day');
c_dia.year             = wsa_find_column(dia_format, 'Year');
c_dia.hour             = wsa_find_column(dia_format, 'Hour');
c_dia.minute           = wsa_find_column(dia_format, 'Minute');
c_dia.second           = wsa_find_column(dia_format, 'Second');
c_dia.burst_counter    = wsa_find_column(dia_format, 'Burst counter');
c_dia.error_code       = wsa_find_column(dia_format, 'Error code'); % +
c_dia.status_code    = wsa_find_column(dia_format, 'Status code'); % +
c_dia.vel1    = wsa_find_column(dia_format, 'Velocity (Beam1'); % +
c_dia.vel2    = wsa_find_column(dia_format, 'Velocity (Beam2'); % +
c_dia.vel3    = wsa_find_column(dia_format, 'Velocity (Beam3'); % +
c_dia.amp1    = wsa_find_column(dia_format, 'Amplitude (Beam1'); % +
c_dia.amp2    = wsa_find_column(dia_format, 'Amplitude (Beam2'); % +
c_dia.amp3    = wsa_find_column(dia_format, 'Amplitude (Beam3'); % +
c_dia.battery_voltage  = wsa_find_column(dia_format, 'Battery voltage');
c_dia.sound_speed      = wsa_find_column(dia_format, 'Soundspeed');
c_dia.heading          = wsa_find_column(dia_format, 'Heading');
c_dia.pitch            = wsa_find_column(dia_format, 'Pitch');
c_dia.roll             = wsa_find_column(dia_format, 'Roll');
c_dia.pressure         = wsa_find_column(dia_format, 'Pressure'); % +
c_dia.temperature      = wsa_find_column(dia_format, 'Temperature');
c_dia.analog1      = wsa_find_column(dia_format, 'Analog input 1'); % +
c_dia.analog2      = wsa_find_column(dia_format, 'Analog input 2'); % +
c_dia.speed      = wsa_find_column(dia_format, 'Speed'); % +
c_dia.direction      = wsa_find_column(dia_format, 'Direction'); % +

%Verificar si existen fechas o burst counter
has_time = ~isempty(c_dia.month)  && ~isempty(c_dia.day)   && ...
           ~isempty(c_dia.year)   && ~isempty(c_dia.hour)  && ...
           ~isempty(c_dia.minute) && ~isempty(c_dia.second);
has_burst_counter = ~isempty(c_dia.burst_counter);

%=== Considerar, para después, si hacer tiempo obligatorio y no tratar de extraer burst_counter
% if ~has_time
%     error('El archivo .dia no contiene las seis columnas de fecha y hora necesarias para segmentar y fechar los bursts diagnósticos.');
% end


% Identificar inicios y finales de cada burst para segmentar archivo .dia
if has_time
    fprintf('\nSegmentando archivo .dia usando tiempo.\n')   
    % Crear vector de fechas
    time = datetime( ...
        dia(:,c_dia.year), ...
        dia(:,c_dia.month), ...
        dia(:,c_dia.day), ...
        dia(:,c_dia.hour), ...
        dia(:,c_dia.minute), ...
        dia(:,c_dia.second));

    % Identificar inicios y finales de cada burst basado en tiempo
    dt = seconds(diff(time));
    threshold = 10;   % segundos, ajustable si necesario
    burst_breaks = find(dt > threshold);
    burst_start = [1; burst_breaks + 1];
    burst_end   = [burst_breaks; length(time)];
    segmentation_method = "time";

elseif has_burst_counter
    
    fprintf('\nSegmentando archivo .dia usando Burst counter.\n')
    
    burst_counter = dia(:,c_dia.burst_counter);
    d_burst = diff(burst_counter);

    % Nuevo burst cuando cambia el burst counter
    burst_breaks = find(d_burst ~= 0);

    burst_start = [1; burst_breaks + 1];
    burst_end   = [burst_breaks; length(burst_counter)];

    segmentation_method = "burst_counter";
else
    error(['No es posible segmentar el archivo .dia en bursts porque no contiene ' ...
           'columnas de tiempo completas ni columna "Burst counter".']);
end



%Struct con los bursts
nBursts_dia_detected = length(burst_start);
wave_data(nBursts_dia_detected,1) = struct();

for b = 1:nBursts_dia_detected

    idx = burst_start(b):burst_end(b);

    if has_time
        wave_data(b).datetime = time(idx);
    else
        wave_data(b).datetime = [];
    end

    if has_burst_counter
        wave_data(b).burst_counter = dia(idx(1), c_dia.burst_counter);
    else
        wave_data(b).burst_counter = [];
    end

    wave_data(b).error_code = dia(idx,c_dia.error_code);
    wave_data(b).status_code = dia(idx,c_dia.status_code);

    wave_data(b).pressure_dbar = dia(idx,c_dia.pressure);

    wave_data(b).beam_velocity_ms = [dia(idx,c_dia.vel1), dia(idx,c_dia.vel2), dia(idx,c_dia.vel3)];
    wave_data(b).amplitude = [dia(idx,c_dia.amp1), dia(idx,c_dia.amp2), dia(idx,c_dia.amp3)];
    
    wave_data(b).battery_voltage_V = dia(idx,c_dia.battery_voltage);
    wave_data(b).sound_speed_ms = dia(idx,c_dia.sound_speed);
    wave_data(b).heading_deg = dia(idx,c_dia.heading);
    wave_data(b).pitch_deg = dia(idx,c_dia.pitch);
    wave_data(b).roll_deg = dia(idx,c_dia.roll);
    wave_data(b).temperature_C = dia(idx,c_dia.temperature);
    wave_data(b).analog1 = dia(idx,c_dia.analog1);
    wave_data(b).analog2 = dia(idx,c_dia.analog2);
    wave_data(b).speed_ms = dia(idx,c_dia.speed);
    wave_data(b).direction_deg = dia(idx,c_dia.direction);

    wave_data(b).nSamples = length(idx);

end

data.dia = wave_data;
data.hdr.dia_segmentation_method = segmentation_method;

fprintf('\nInformación de archivo .dia extraida correctamente.\n')

%% Guardar paths de archivos leidos en struct
data.hdr.file_paths.hdr = file_hdr;
data.hdr.file_paths.dat = file_dat;
data.hdr.file_paths.dia = file_dia;

%% Información por burst

nBursts = numel(data.dia);

nBursts_dia = numel(burst_start);
diagnostic_info(nBursts_dia,1) = struct();

for b = 1:nBursts_dia

    idx = burst_start(b):burst_end(b);

    heading_b = dia(idx,c_dia.heading);
    pitch_b   = dia(idx,c_dia.pitch);
    roll_b    = dia(idx,c_dia.roll);
    pressure_b = dia(idx,c_dia.pressure);

    % Heading medio circular.
    mean_sin = mean(sind(heading_b), 'omitnan');
    mean_cos = mean(cosd(heading_b), 'omitnan');

    heading_mean = mod(atan2d(mean_sin, mean_cos), 360);

    % Tilt para cada muestra.
    cos_tilt_b = cosd(pitch_b).*cosd(roll_b);
    cos_tilt_b = max(-1, min(1, cos_tilt_b));
    tilt_b = acosd(cos_tilt_b);

    diagnostic_info(b).burst_index = b;

    diagnostic_info(b).datetime = time(idx(1));
    diagnostic_info(b).end_datetime = time(idx(end));
    diagnostic_info(b).n_diagnostic_records = numel(idx);
    diagnostic_info(b).heading_deg = heading_mean;
    diagnostic_info(b).pitch_deg = median(pitch_b, 'omitnan');
    diagnostic_info(b).roll_deg = median(roll_b, 'omitnan');
    diagnostic_info(b).tilt_deg = median(tilt_b, 'omitnan');
    diagnostic_info(b).max_tilt_deg = max(tilt_b, [], 'omitnan');
    diagnostic_info(b).mean_pressure_dbar = mean(pressure_b, 'omitnan');
    diagnostic_info(b).min_pressure_dbar = min(pressure_b, [], 'omitnan');
    diagnostic_info(b).max_pressure_dbar = max(pressure_b, [], 'omitnan');
    diagnostic_info(b).battery_voltage_V = median(dia(idx,c_dia.battery_voltage), 'omitnan');
    diagnostic_info(b).sound_speed_ms = median(dia(idx,c_dia.sound_speed), 'omitnan');
    diagnostic_info(b).temperature_degC = median(dia(idx,c_dia.temperature), 'omitnan');
end

data.dia_info = diagnostic_info;

burst_index = (1:nBursts)';

%% Inicializar banderas de calidad de los datos

empty_flags = struct( ...
    'samples_flag', false, ...
    'heading_jump_flag', false, ...
    'tilt_jump_flag', false, ...
    'orientation_flag', false, ...
    'warning_tilt_flag_5', false, ...
    'warning_tilt_flag_20', false, ...
    'bad_tilt_flag', false, ...
    'pressure_flag', false, ...
    'pressure_sample_flag', false);

data.quality.flags = repmat(empty_flags, nBursts, 1);

%% Verificación de calidad de los datos #1
%
% Verificaciones realizadas:
%   -Cantidad de bursts deben coincidir en .dat y .dia.
%   -Número de muestras de cada burst en .dia debe coincidir con el número
%    de muestras por burst indicados en .dat.

% Verificación en espera de revisión, se debe adecuar.

fprintf('\n-------------------------------           Verificación del tamaño de los datos          -------------------------------\n');


% Verificación de número de muestras por burst.
fprintf('\nVerificando consistencia en cantidad de muestras por burst...\n')

mismatch = false;
expected_samples = data.hdr.setup.Diagnostics_Number_of_samples;
actual_samples = [data.dia.nSamples]';
samples_flag = actual_samples ~= expected_samples;

for b = 1:nBursts
    data.quality.flags(b).samples_flag = samples_flag(b);
end

for b = 1:nBursts
    if expected_samples ~= actual_samples(b)
        fprintf('\tBurst %d: esperado %d muestras, encontrado %d.\n', ...
            b, expected_samples, actual_samples(b));
        mismatch = true;
    end
end

if ~mismatch
    fprintf('\tVerificación de muestras OK: la cantidad de muestras de todos los bursts de .dia coincide con la indicada en el .hdr.\n');
end

%Graficar si se indica
if do_plot

    expected_vec = repmat(expected_samples, nBursts, 1);
    actual_vec   = actual_samples;

    bad_size_idx = find(samples_flag);

    f = figure('Name', 'Verificación de cantidad de muestras', 'Color', 'w');

    f.Position = [1, 1, 1900, 1000];

    hold on

    t = title('Verificación del número de muestras por burst');
    xl = xlabel('Burst');
    yl = ylabel('Número de muestras');

    plot(burst_index, expected_vec, '-', 'DisplayName', 'Esperado (.hdr)', 'LineWidth', 2);

    plot(burst_index, actual_vec, '-', 'DisplayName', 'Actual (.dia)', 'LineWidth', 1.5);

    if ~isempty(bad_size_idx)
        scatter(burst_index(bad_size_idx), actual_vec(bad_size_idx), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
    end

    hold off

    ylim([0, max([expected_vec; actual_vec], [], 'omitnan') + 200])

    l = legend('Location', 'best');
    grid on
    box on

    t.FontSize  = 16;
    xl.FontSize = 14;
    yl.FontSize = 14;
    l.FontSize  = 12;

    if ~isempty(save_plot_dir)
        exportgraphics(f, fullfile(save_plot_dir, 'verificacion_cantidad_muestras.png'), 'Resolution', 300);
    end
end

% 
% % Verificación temporal
% if has_time
%     fprintf('\nVerificando existencia de desplazamientos temporales en bursts...\n')
%     time_mismatch = false;
%     for b = 1:minBursts
%         t_dat = data.dat(b).datetime;
%         t_dia = data.dia(b).datetime(1);
%         dt_seconds = abs(seconds(t_dia - t_dat));
%         if dt_seconds > 1   % tolerancia de 1 segundo
%             warning(['\tBurst %d: diferencia temporal entre .dat y .dia = %.2f s ' ...
%                      '(dat: %s | dia: %s)\n'], ...
%                      b, dt_seconds, string(t_dat), string(t_dia));
%             time_mismatch = true;
%         end
%     end
%     if ~time_mismatch
%         fprintf('\tVerificación temporal OK: todos los bursts están alineados.\n');
%     end
% else
%     fprintf('\nVerificación temporal omitida: el archivo .dia no contiene tiempo.\n')
% end


%% Verificación de calidad de los datos #2

fprintf('\n-------------------          Verificación de orientación de los datos (Heave, Pitch y Roll)         -------------------\n');

fprintf('\nLímites establecidos:\n')
%fprintf('\t-Pitch máximo: %d °\n', pitch_limit)
%fprintf('\t-Roll máximo: %d °\n', roll_limit)
fprintf('\t-Tilt máximo: %d °\n', tilt_limit)
fprintf('\t-Cambio máximo en heading: %d °\n', heading_jump_limit)
fprintf('\t-Cambio máximo en tilt: %d °\n\n', tilt_jump_limit)

heading = [data.dia_info.heading_deg]';
pitch   = [data.dia_info.pitch_deg]';
roll    = [data.dia_info.roll_deg]';
tilt    = [data.dia_info.tilt_deg]';
maximum_tilt = [data.dia_info.max_tilt_deg]';

% 1) Límites absolutos
bad_tilt_flag = maximum_tilt > tilt_limit;
warning_tilt_flag_5 = tilt > 5;             % Si tilt es mayor a 5° guardar flag de warning.
warning_tilt_flag_20 = tilt > 20;         % Si tilt es mayor a 20° guardar flag de warning, ya que todas las mediciones son inutilizables.

% 2) Cambios bruscos entre bursts

% Cambios individuales
d_heading = abs(diff(heading));
d_pitch   = abs(diff(pitch));
d_roll    = abs(diff(roll));

% Corregir wrapping de heading (0–360)
d_heading = min(d_heading, 360 - d_heading);

% Cambio en la magnitud absoluta del tilt
d_tilt_magnitude = abs(diff(tilt));

% Vectores unitarios del eje Z del instrumento.
% Heading se omite porque se controla independientemente.
z_x = sind(pitch).*cosd(roll);
z_y = -sind(roll);
z_z = cosd(pitch).*cosd(roll);

% Producto punto entre orientaciones consecutivas
dot_z = z_x(1:end-1).*z_x(2:end) + ...
        z_y(1:end-1).*z_y(2:end) + ...
        z_z(1:end-1).*z_z(2:end);

% Protección numérica para acosd
dot_z = max(-1, min(1, dot_z));

% Cambio angular de la inclinación
d_tilt_axis = acosd(dot_z);

% Flags de jump, separados
heading_jump_flag = [false; d_heading > heading_jump_limit];
tilt_jump_flag = [false; d_tilt_axis > tilt_jump_limit];

% Flag general de orientación
orientation_flag = bad_tilt_flag | heading_jump_flag | tilt_jump_flag;

% Guardar flags
for b = 1:nBursts
    data.quality.flags(b).heading_jump_flag = heading_jump_flag(b);
    data.quality.flags(b).tilt_jump_flag = tilt_jump_flag(b);
    data.quality.flags(b).orientation_flag = orientation_flag(b);
    data.quality.flags(b).warning_tilt_flag_5 = warning_tilt_flag_5(b);
    data.quality.flags(b).warning_tilt_flag_20 = warning_tilt_flag_20(b);
    data.quality.flags(b).bad_tilt_flag = bad_tilt_flag(b);
    if orientation_flag(b)
        fprintf('Burst %d presenta problemas de orientación. Tilt, cambio en heading o cambio en tilt mayor al límite establecido.\n', b)
    end

    if warning_tilt_flag_5(b)
        if warning_tilt_flag_20(b)
            fprintf('Burst %d presenta un tilt mayor a 20°, todas las mediciones podrían ser inutilizables.\n', b)
        else
            fprintf('Burst %d presenta un tilt mayor a 5°, mediciones podrían estar afectadas.\n', b)
        end
    end
end

fprintf('\nResumen: %d bursts marcados como problemáticos.\n', ...
    sum(orientation_flag));

if do_plot

    % Cambios alineados con la ráfaga posterior.
    d_heading_plot      = [NaN; d_heading];
    d_tilt_axis_plot    = [NaN; d_tilt_axis];

    f = figure('Name', 'Verificación de orientación', 'Color', 'w');

    f.Position = [1, 1, 1900, 1000];

    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    %% Valores absolutos

    nexttile
    hold on

    t1 = title('Verificación de orientación: valores absolutos');
    xl1 = xlabel('Burst');
    yl1 = ylabel('Ángulo (°)');

    plot(burst_index, heading, '-', 'DisplayName', 'Heading');

    plot(burst_index, tilt, '-',  'DisplayName', 'Tilt');

    plot(burst_index, maximum_tilt, ':', 'DisplayName', 'Tilt máximo');

    yline(5, ':', 'DisplayName', 'Advertencia de tilt');

    yline(tilt_limit, '--', 'DisplayName', 'Límite máximo de tilt');

    if any(bad_tilt_flag)
        scatter(burst_index(bad_tilt_flag), maximum_tilt(bad_tilt_flag), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
    end

    hold off

    l1 = legend('Location', 'best');
    grid on
    box on

    t1.FontSize  = 16;
    xl1.FontSize = 14;
    yl1.FontSize = 14;
    l1.FontSize  = 12;

    %% Cambios entre ráfagas

    nexttile
    hold on

    t2 = title('Verificación de orientación: cambios entre ráfagas');
    xl2 = xlabel('Burst');
    yl2 = ylabel('\Delta ángulo (°)');

    plot(burst_index, d_heading_plot, '-', 'DisplayName', '\Delta Heading');

    plot(burst_index, d_tilt_axis_plot, '-', 'DisplayName', '\Delta Tilt');

    yline(heading_jump_limit, '--', 'DisplayName', 'Límite de salto en heading');
    yline(tilt_jump_limit, ':', 'DisplayName', 'Límite de salto en tilt');

    if any(heading_jump_flag)
        scatter(burst_index(heading_jump_flag), d_heading_plot(heading_jump_flag), 40, 'r', 'filled', 'DisplayName', 'Salto de heading', 'HandleVisibility','off');
    end

    if any(tilt_jump_flag)
        scatter(burst_index(tilt_jump_flag), d_tilt_axis_plot(tilt_jump_flag), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
    end

    hold off

    l2 = legend('Location', 'best');
    grid on
    box on

    t2.FontSize  = 16;
    xl2.FontSize = 14;
    yl2.FontSize = 14;
    l2.FontSize  = 12;

    if ~isempty(save_plot_dir)
        exportgraphics(f, fullfile(save_plot_dir, 'verificacion_orientacion.png'), 'Resolution', 300);
    end
end



fprintf('\n-----------------------------------              Verificación de presión             ----------------------------------\n');
fprintf('\nLímites establecidos:\n')
fprintf('\t-Presión mínima: %d dbar\n', min_pressure_limit)
fprintf('\t-Diferencia de presión respecto a la mediana: %d dbar\n\n', pressure_drop_limit)

% Se realiza una verificación de la presión siguiendo los siguientes
% criterios:
%
%   1) Presión media del burst
%       Se verifica la presión media del burst y se compara con una presión
%       mínima y límites +-mediana. Se marca el burst si la presión mínima
%       supera alguno de los criterios.

mean_pressure = [data.dia_info.mean_pressure_dbar]';
median_pressure = median(mean_pressure, 'omitnan');

bad_pressure = isnan(mean_pressure) | mean_pressure < min_pressure_limit | abs(mean_pressure - median_pressure) > pressure_drop_limit;

for b = 1:nBursts
    data.quality.flags(b).pressure_flag = bad_pressure(b);
    if bad_pressure(b)
        fprintf('Burst %d presenta problemas de presión media\n', b)
    end
end


if do_plot

    f = figure('Name', 'Verificación de presión', 'Color', 'w');

    f.Position = [1, 1, 1900, 1000];

    hold on

    t = title('Verificación de presión media por burst');
    xl = xlabel('Burst');
    yl = ylabel('Presión media (dbar)');

    plot(burst_index, mean_pressure, '-', 'DisplayName', 'Presión media', 'LineWidth', 1.5);

    yline(min_pressure_limit, '--', 'DisplayName', 'Presión mínima');
    yline(median_pressure, '-', 'DisplayName', 'Mediana');
    yline(median_pressure + pressure_drop_limit, ':', 'DisplayName', 'Mediana + límite');
    yline(median_pressure - pressure_drop_limit, ':', 'DisplayName', 'Mediana - límite');

    if any(bad_pressure)
        scatter(burst_index(bad_pressure), mean_pressure(bad_pressure), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
    end

    hold off

    l = legend('Location', 'best');
    grid on
    box on

    t.FontSize  = 16;
    xl.FontSize = 14;
    yl.FontSize = 14;
    l.FontSize  = 12;

    if ~isempty(save_plot_dir)
        exportgraphics(f, fullfile(save_plot_dir, 'verificacion_presion.png'), 'Resolution', 300);
    end
end

%   2) Porcentaje de samples de presión por debajo de umbral
%       Se verifica, para cada burst, la cantidad de samples que se
%       encuentran debajo del umbral establecido. Se elimina el burst si la
%       cantidad de samples de baja presión superan un porcentaje deseado.

bad_pressure_sample_percentage = NaN(nBursts,1);
for b = 1:nBursts
    p = data.dia(b).pressure_dbar;
    idx_bad = p < min_pressure_limit;
    bad_pressure_sample_percentage(b) = 100*sum(idx_bad)/numel(p);
end

sample_pressure_flag = bad_pressure_sample_percentage > bad_pressure_sample_percentage_limit;

for b = 1:nBursts
    data.quality.flags(b).pressure_sample_flag = sample_pressure_flag(b);
    if sample_pressure_flag(b)
        fprintf('Burst %d presenta presión menor a %.2f dbar en un %.2f %% de las muestras.\n', b, min_pressure_limit, bad_pressure_sample_percentage(b))
    end
end

if do_plot

    f = figure( ...
        'Name', 'Verificación de muestras de presión', ...
        'Color', 'w');

    f.Position = [1, 1, 1900, 1000];

    hold on

    t = title(['Verificación de muestras de presión: ' 'porcentaje superior límite']);

    xl = xlabel('Burst');
    yl = ylabel('Porcentaje (%)');

    plot(burst_index, bad_pressure_sample_percentage, '-', 'DisplayName', 'Porcentaje superior al límite', 'LineWidth', 1.5);

    yline(bad_pressure_sample_percentage_limit, '--', 'DisplayName', 'Porcentaje máximo');

    if any(sample_pressure_flag)
        scatter(burst_index(sample_pressure_flag), bad_pressure_sample_percentage(sample_pressure_flag), 40, 'r', 'filled', 'DisplayName', 'Burst marcado');
    end

    hold off

    l = legend('Location', 'best');
    grid on
    box on

    t.FontSize  = 16;
    xl.FontSize = 14;
    yl.FontSize = 14;
    l.FontSize  = 12;

    if ~isempty(save_plot_dir)
        exportgraphics(f, fullfile(save_plot_dir, 'verificacion_presion_muestras.png'), 'Resolution', 300);
    end
end


fprintf('\nResumen: %d bursts marcados como problemáticos.\n', sum(bad_pressure | sample_pressure_flag));

%% Resumen

fprintf('\n----------------------------------              Resumen de verificaciones             ---------------------------------\n');

samples_flag = [data.quality.flags.samples_flag]';
orientation_flag = [data.quality.flags.orientation_flag]';
pressure_flag    = [data.quality.flags.pressure_flag]';
pressure_sample_flag = [data.quality.flags.pressure_sample_flag]';

bad_bursts = samples_flag | orientation_flag | pressure_flag | pressure_sample_flag;

fprintf('\nTotal bursts malos detectados: %d de %d\n', ...
    sum(bad_bursts), length(bad_bursts));



qc_summary = struct();

qc_summary.total_bursts = nBursts;

qc_summary.samples_flag_count     = sum(samples_flag);
qc_summary.orientation_flag_count = sum(orientation_flag);
qc_summary.pressure_flag_count    = sum(pressure_flag);
qc_summary.pressure_sample_flag_count    = sum(pressure_sample_flag);

qc_summary.bad_bursts = bad_bursts;
qc_summary.total_bad_bursts = sum(bad_bursts);
qc_summary.total_good_bursts = sum(~bad_bursts);

qc_summary.percentage_bad = ...
    100 * qc_summary.total_bad_bursts / qc_summary.total_bursts;

qc_summary.bad_indices  = find(bad_bursts);
qc_summary.good_indices = find(~bad_bursts);

% Rango temporal total
qc_summary.time_start = data.dia_info(1).datetime;
qc_summary.time_end   = data.dia_info(end).end_datetime;

% Rango temporal de bursts malos (si existen)
if any(bad_bursts)
    qc_summary.bad_datetimes =[data.dia_info(bad_bursts).datetime]';
else
    qc_summary.bad_datetimes = datetime.empty(0,1);
end

% Guardar en struct principal
data.quality.summary = qc_summary;

% Guardar numero de mediciones de olas
data.hdr.general.Number_of_diagnostic_bursts = nBursts;

data.cleaning_status = false;
data.preprocessing_status = false;

fprintf('\n========================================================================================================================\n');
end

