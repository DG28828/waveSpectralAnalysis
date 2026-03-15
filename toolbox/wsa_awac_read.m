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
pitch_limit_default         = 10;    % grados
roll_limit_default          = 10;    % grados
heading_jump_limit_default  = 20;    % cambio brusco entre bursts
tilt_jump_limit_default     = 5;     % cambio brusco pitch/roll
min_pressure_limit_default  = 1;     % dbar (casi fuera del agua)
pressure_drop_limit_default = 5;     % dbar respecto a mediana
plot_default                = false; % No graficar por defecto
save_plot_dir_default       = [];    % Vacio por defecto

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
addParameter(p, 'do_plot', plot_default)
addParameter(p, 'save_plot_dir', save_plot_dir_default)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, files_dir, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
pitch_limit         = p.Results.pitch_limit;        
roll_limit          = p.Results.roll_limit;         
heading_jump_limit  = p.Results.heading_jump_limit;    
tilt_jump_limit     = p.Results.tilt_jump_limit;
min_pressure_limit  = p.Results.min_pressure_limit;
pressure_drop_limit = p.Results.pressure_drop_limit;
do_plot             = p.Results.do_plot;
save_plot_dir       = p.Results.save_plot_dir;  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('===========================================          Lectura de AWAC         ===========================================\n');
fprintf('\nLeer datos de archivos crudos de AWAC.\n');

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

setup.Profile_interval_s          = wsa_getNumField(hdr_txt, 'Profile interval');
setup.Number_of_cells             = wsa_getNumField(hdr_txt, 'Number of cells');
setup.Cell_size_m                 = wsa_getNumField(hdr_txt, 'Cell size') / 100;   % cm -> m
setup.Average_interval_s          = wsa_getNumField(hdr_txt, 'Average interval');
setup.Measurement_load_percent    = wsa_getNumField(hdr_txt, 'Measurement load');
setup.Transmit_pulse_length_m     = wsa_getNumField(hdr_txt, 'Transmit pulse length');
setup.Blanking_distance_m         = wsa_getNumField(hdr_txt, 'Blanking distance');
setup.Compass_update_rate_s       = wsa_getNumField(hdr_txt, 'Compass update rate');

setup.Wave_measurements           = wsa_getStrField(hdr_txt, 'Wave measurements');
setup.Wave_Powerlevel             = wsa_getStrField(hdr_txt, 'Wave - Powerlevel');
setup.Wave_Interval_s             = wsa_getNumField(hdr_txt, 'Wave - Interval');
setup.Wave_Number_of_samples      = wsa_getNumField(hdr_txt, 'Wave - Number of samples');
setup.Wave_Sampling_rate_Hz       = wsa_getNumField(hdr_txt, 'Wave - Sampling rate');
setup.Wave_SUV_data_collection    = wsa_getStrField(hdr_txt, 'Wave - SUV data collection');
setup.Wave_Ice_data_collection    = wsa_getStrField(hdr_txt, 'Wave - Ice data collection');
setup.Onboard_wave_processing     = wsa_getStrField(hdr_txt, 'Onboard wave processing');

setup.Analog_input_1              = wsa_getStrField(hdr_txt, 'Analog input 1');
setup.Analog_input_2              = wsa_getStrField(hdr_txt, 'Analog input 2');
setup.Power_output                = wsa_getStrField(hdr_txt, 'Power output');
setup.Powerlevel                  = wsa_getStrField(hdr_txt, 'Powerlevel');
setup.Coordinate_system           = wsa_getStrField(hdr_txt, 'Coordinate system');
setup.Sound_speed_mode            = wsa_getStrField(hdr_txt, 'Sound speed');
setup.Salinity_ppt                = wsa_getNumField(hdr_txt, 'Salinity');
setup.Distance_between_pings_m    = wsa_getNumField(hdr_txt, 'Distance between pings');
setup.Number_of_beams             = wsa_getNumField(hdr_txt, 'Number of beams');
setup.Number_of_pings_per_burst   = wsa_getNumField(hdr_txt, 'Number of pings per burst');
setup.Software_version            = wsa_getStrField(hdr_txt, 'Software version');
setup.Deployment_name             = wsa_getStrField(hdr_txt, 'Deployment name');
setup.Wrap_mode                   = wsa_getStrField(hdr_txt, 'Wrap mode');
setup.Deployment_time             = wsa_getDateField(hdr_txt, 'Deployment time');
setup.Comments                    = wsa_getTextField(hdr_txt, 'Comments');
setup.Start_command               = wsa_getTextField(hdr_txt, 'Start command');
setup.CRC_download                = wsa_getStrField(hdr_txt, 'CRC download');

%Calculado
% Derivadas útiles
if ~isnan(setup.Wave_Number_of_samples) && ~isnan(setup.Wave_Sampling_rate_Hz) && setup.Wave_Sampling_rate_Hz > 0
    setup.Wave_burst_duration_s = setup.Wave_Number_of_samples / setup.Wave_Sampling_rate_Hz;
    setup.Wave_Nyquist_frequency_Hz = setup.Wave_Sampling_rate_Hz / 2;
    setup.Wave_frequency_resolution_Hz = setup.Wave_Sampling_rate_Hz / setup.Wave_Number_of_samples;
else
    setup.Wave_burst_duration_s = NaN;
    setup.Wave_Nyquist_frequency_Hz = NaN;
    setup.Wave_frequency_resolution_Hz = NaN;
end
if ~isnat(general.Time_of_first_measurement) && ~isnat(general.Time_of_last_measurement) ...
        && ~isnan(setup.Wave_Interval_s) && setup.Wave_Interval_s > 0
    total_seconds = seconds(general.Time_of_last_measurement - general.Time_of_first_measurement);
    setup.Expected_number_of_wave_bursts = floor(total_seconds / setup.Wave_Interval_s) + 1;
else
    setup.Expected_number_of_wave_bursts = NaN;
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

hardware.Analog_input_1_calibration       = wsa_getNumArrayField(hardware_block, 'Analog input #1 calibration \(a0, a1\)');
hardware.Analog_input_2_calibration       = wsa_getNumArrayField(hardware_block, 'Analog input #2 calibration \(a0, a1\)');

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
    'Head configuration\s*-+\s*(.*?)\s*Current profile cell center distance', ...
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

%Formato de archivos .whd y .wad indicado en .hdr
data.hdr.files_format = struct();
data.hdr.files_format.whd = wsa_parse_hdr_data_format(hdr_txt, '.whd');
data.hdr.files_format.wad = wsa_parse_hdr_data_format(hdr_txt, '.wad');
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
    warning(['El sistema de coordenadas del AWAC es "%s". ' ...
             'La función asume coordenadas ENU (East-North-Up). ' ...
             'Los resultados podrían ser incorrectos.'], coord_system);
else  
    fprintf('Sistema de coordenadas OK: ENU.\n')
end
%-------------------------------------------------------------------------%

%% Leer el archivo .whd

fprintf('\n-------------------------------          Extrayendo información de archivo .whd         -------------------------------\n');

whd = load(file_whd);

whd_format = data.hdr.files_format.whd;

% Verificación contra formato definido en .hdr
ncols_whd_expected = data.hdr.files_format.whd.n_columns;
ncols_whd_actual   = size(whd,2);
if ncols_whd_actual ~= ncols_whd_expected
    error(['\nEl archivo .whd tiene %d columnas, pero el .hdr define %d ' ...
           'columnas para este archivo.'], ...
           ncols_whd_actual, ncols_whd_expected);
end


N = size(whd,1);
wave_info(N,1) = struct();

% Índices de columnas .whd según el .hdr
c_whd.month            = wsa_find_column(whd_format, 'Month');
c_whd.day              = wsa_find_column(whd_format, 'Day');
c_whd.year             = wsa_find_column(whd_format, 'Year');
c_whd.hour             = wsa_find_column(whd_format, 'Hour');
c_whd.minute           = wsa_find_column(whd_format, 'Minute');
c_whd.second           = wsa_find_column(whd_format, 'Second');
c_whd.burst_counter    = wsa_find_column(whd_format, 'Burst counter');
c_whd.n_wave_records   = wsa_find_column(whd_format, 'No of wave data records');
c_whd.cell_position    = wsa_find_column(whd_format, 'Cell position');
c_whd.battery_voltage  = wsa_find_column(whd_format, 'Battery voltage');
c_whd.sound_speed      = wsa_find_column(whd_format, 'Soundspeed');
c_whd.heading          = wsa_find_column(whd_format, 'Heading');
c_whd.pitch            = wsa_find_column(whd_format, 'Pitch');
c_whd.roll             = wsa_find_column(whd_format, 'Roll');
c_whd.min_pressure     = wsa_find_column(whd_format, 'Minimum pressure');
c_whd.max_pressure     = wsa_find_column(whd_format, 'Maximum pressure');
c_whd.temperature      = wsa_find_column(whd_format, 'Temperature');
c_whd.cell_size        = wsa_find_column(whd_format, 'CellSize');
c_whd.noise_amp_b1     = wsa_find_column(whd_format, 'Noise amplitude beam 1');
c_whd.noise_amp_b2     = wsa_find_column(whd_format, 'Noise amplitude beam 2');
c_whd.noise_amp_b3     = wsa_find_column(whd_format, 'Noise amplitude beam 3');
c_whd.noise_amp_b4     = wsa_find_column(whd_format, 'Noise amplitude beam 4');
c_whd.ast_start        = wsa_find_column(whd_format, 'AST window start');
c_whd.ast_size         = wsa_find_column(whd_format, 'AST window size');
c_whd.ast_offset       = wsa_find_column(whd_format, 'AST window offset');

for i = 1:N
    wave_info(i).datetime = datetime( ...
        whd(i,c_whd.year), ...
        whd(i,c_whd.month), ...
        whd(i,c_whd.day), ...
        whd(i,c_whd.hour), ...
        whd(i,c_whd.minute), ...
        whd(i,c_whd.second));

    wave_info(i).burst_counter       = whd(i,c_whd.burst_counter);
    wave_info(i).n_wave_records      = whd(i,c_whd.n_wave_records);
    wave_info(i).cell_position_m     = whd(i,c_whd.cell_position);
    wave_info(i).battery_voltage_V   = whd(i,c_whd.battery_voltage);
    wave_info(i).sound_speed_ms      = whd(i,c_whd.sound_speed);
    wave_info(i).heading_deg         = whd(i,c_whd.heading);
    wave_info(i).pitch_deg           = whd(i,c_whd.pitch);
    wave_info(i).roll_deg            = whd(i,c_whd.roll);
    wave_info(i).min_pressure_dbar   = whd(i,c_whd.min_pressure);
    wave_info(i).max_pressure_dbar   = whd(i,c_whd.max_pressure);
    wave_info(i).temperature_degC    = whd(i,c_whd.temperature);
    wave_info(i).cell_size_m         = whd(i,c_whd.cell_size);

    wave_info(i).noise_amp_beams = [ ...
        whd(i,c_whd.noise_amp_b1), ...
        whd(i,c_whd.noise_amp_b2), ...
        whd(i,c_whd.noise_amp_b3), ...
        whd(i,c_whd.noise_amp_b4)];

    wave_info(i).ast_window_start_m  = whd(i,c_whd.ast_start);
    wave_info(i).ast_window_size_m   = whd(i,c_whd.ast_size);
    wave_info(i).ast_window_offset_m = whd(i,c_whd.ast_offset);

end

data.whd = wave_info;
nBursts_whd = length(data.whd);

fprintf('\nInformación de archivo .whd extraida correctamente.\n')


% Verificación de configuración de muestras de oleaje
fprintf('\nVerificando consistencia entre configuración de oleaje y .whd...\n')

expected_samples = data.hdr.setup.Wave_Number_of_samples;

wave_records = [data.whd.n_wave_records]';

samples_flag = false(nBursts_whd,1);

mismatch_found = false;

for b = 1:nBursts_whd
    
    if wave_records(b) ~= expected_samples
        
        fprintf('Burst %d: n_wave_records = %d, esperado = %d\n', ...
            b, wave_records(b), expected_samples);
        
        samples_flag(b) = true;
        mismatch_found = true;
        
    end
    
end

if ~mismatch_found
    fprintf('Verificación OK: todos los bursts tienen el número esperado de muestras.\n')
end


%% Leer el archivo .wad

fprintf('\n-------------------------------          Extrayendo información de archivo .wad         -------------------------------\n');

wad = load(file_wad);

wad_format = data.hdr.files_format.wad;

% Verificación contra formato definido en .hdr
ncols_wad_expected = wad_format.n_columns;
ncols_wad_actual   = size(wad,2);
if ncols_wad_actual ~= ncols_wad_expected
    error(['El archivo .wad tiene %d columnas, pero el .hdr define %d columnas ' ...
           'para este archivo.'], ncols_wad_actual, ncols_wad_expected);
end

% Índices de columnas .wad según el .hdr
c_wad.month         = wsa_find_column(wad_format, 'Month');
c_wad.day           = wsa_find_column(wad_format, 'Day');
c_wad.year          = wsa_find_column(wad_format, 'Year');
c_wad.hour          = wsa_find_column(wad_format, 'Hour');
c_wad.minute        = wsa_find_column(wad_format, 'Minute');
c_wad.second        = wsa_find_column(wad_format, 'Second');
c_wad.burst_counter = wsa_find_column(wad_format, 'Burst counter');
c_wad.pressure      = wsa_find_column(wad_format, 'Pressure');
c_wad.ast_distance1 = wsa_find_column(wad_format, 'AST Distance1');
c_wad.ast_distance2 = wsa_find_column(wad_format, 'AST Distance2');
c_wad.ast_quality   = wsa_find_column(wad_format, 'AST Quality');
c_wad.analog_input  = wsa_find_column(wad_format, 'Analog input');
c_wad.vel1          = wsa_find_column(wad_format, 'Velocity (Beam1');
c_wad.vel2          = wsa_find_column(wad_format, 'Velocity (Beam2');
c_wad.vel3          = wsa_find_column(wad_format, 'Velocity (Beam3');
c_wad.amp1          = wsa_find_column(wad_format, 'Amplitude (Beam1');
c_wad.amp2          = wsa_find_column(wad_format, 'Amplitude (Beam2');
c_wad.amp3          = wsa_find_column(wad_format, 'Amplitude (Beam3');

%Verificar si existen fechas o burst counter
has_time = ~isempty(c_wad.month)  && ~isempty(c_wad.day)   && ...
           ~isempty(c_wad.year)   && ~isempty(c_wad.hour)  && ...
           ~isempty(c_wad.minute) && ~isempty(c_wad.second);
has_burst_counter = ~isempty(c_wad.burst_counter);


% Identificar inicios y finales de cada burst para segmentar archivo .wad
if has_time
    fprintf('\nSegmentando archivo .wad usando tiempo.\n')   
    % Crear vector de fechas
    time = datetime( ...
        wad(:,c_wad.year), ...
        wad(:,c_wad.month), ...
        wad(:,c_wad.day), ...
        wad(:,c_wad.hour), ...
        wad(:,c_wad.minute), ...
        wad(:,c_wad.second));

    % Identificar inicios y finales de cada burst basado en tiempo
    dt = seconds(diff(time));
    threshold = 5;   % segundos, ajustable si necesario

    burst_breaks = find(dt > threshold);

    burst_start = [1; burst_breaks + 1];
    burst_end   = [burst_breaks; length(time)];

    segmentation_method = "time";

elseif has_burst_counter
    
    fprintf('\nSegmentando archivo .wad usando Burst counter.\n')
    
    burst_counter = wad(:,c_wad.burst_counter);
    d_burst = diff(burst_counter);

    % Nuevo burst cuando cambia el burst counter
    burst_breaks = find(d_burst ~= 0);

    burst_start = [1; burst_breaks + 1];
    burst_end   = [burst_breaks; length(burst_counter)];

    segmentation_method = "burst_counter";
else
    error(['No es posible segmentar el archivo .wad en bursts porque no contiene ' ...
           'columnas de tiempo completas ni columna "Burst counter".']);
end



%Struct con los bursts
nBursts_wad_detected = length(burst_start);
wave_data(nBursts_wad_detected,1) = struct();

for b = 1:nBursts_wad_detected

    idx = burst_start(b):burst_end(b);

    if has_time
        wave_data(b).datetime = time(idx);
    else
        wave_data(b).datetime = [];
    end

    if has_burst_counter
        wave_data(b).burst_counter = wad(idx(1), c_wad.burst_counter);
    else
        wave_data(b).burst_counter = [];
    end

    wave_data(b).pressure_dbar = wad(idx,c_wad.pressure);

    wave_data(b).ast_distance_m = [ ...
        wad(idx,c_wad.ast_distance1), ...
        wad(idx,c_wad.ast_distance2)];

    wave_data(b).ast_quality  = wad(idx,c_wad.ast_quality);
    wave_data(b).analog_input = wad(idx,c_wad.analog_input);

    wave_data(b).velocity_ms = [ ...
        wad(idx,c_wad.vel1), ...
        wad(idx,c_wad.vel2), ...
        wad(idx,c_wad.vel3)];

    wave_data(b).amplitude = [ ...
        wad(idx,c_wad.amp1), ...
        wad(idx,c_wad.amp2), ...
        wad(idx,c_wad.amp3)];

    wave_data(b).nSamples = length(idx);

end

data.wad = wave_data;
data.hdr.wad_segmentation_method = segmentation_method;

fprintf('\nInformación de archivo .wad extraida correctamente.\n')

%% Guardar paths de archivos leidos en struct
data.hdr.file_paths.hdr = file_hdr;
data.hdr.file_paths.whd = file_whd;
data.hdr.file_paths.wad = file_wad;

%% Verificación de calidad de los datos #1
%
% Verificaciones realizadas:
%   -Cantidad de bursts deben coincidir en .whd y .wad.
%   -Número de muestras de cada burst en .wad debe coincidir con el número
%    de muestras por burst indicados en .whd.

fprintf('\n-------------------------------           Verificación del tamaño de los datos          -------------------------------\n');

% Verificación de cantidad de bursts.
fprintf('\nVerificando consistencia en cantidad de bursts...\n')
nBursts_wad = length(data.wad);
burst_mismatch = false;
if nBursts_whd ~= nBursts_wad
    warning('\tNúmero de bursts distinto entre .whd (%d) y .wad (%d).\n', ...
        nBursts_whd, nBursts_wad);
    burst_mismatch = true;
end
if ~burst_mismatch
    fprintf('\tVerificación de bursts OK: la cantidad de bursts entre .whd y .wad coincide.\n');
end

for b = 1:nBursts_whd
    data.quality.flags(b).samples_flag = samples_flag(b);
end


% Verificación de número de muestras por burst.
fprintf('\nVerificando consistencia en cantidad de muestras por burst...\n')
minBursts = min(nBursts_whd, nBursts_wad);
size_flag = false(nBursts_whd,1);
mismatch = false;
for b = 1:minBursts
    expected = data.whd(b).n_wave_records;
    actual   = data.wad(b).nSamples;
    if expected ~= actual
        fprintf('\tBurst %d: esperado %d muestras, encontrado %d.\n', ...
            b, expected, actual);
        size_flag(b) = true;
        mismatch = true;
    end
end
if nBursts_whd > nBursts_wad
    size_flag((minBursts + 1):nBursts_whd) = true;
    mismatch = true;
    fprintf(['\tFaltan %d bursts en .wad para completar lo reportado en .whd. ' ...
             'Los bursts %d a %d se marcaron con size_flag.\n'], ...
             nBursts_whd - nBursts_wad, minBursts + 1, nBursts_whd);
end
if ~mismatch
    fprintf('\tVerificación de muestras OK: la cantidad de muestras de todos los bursts de .wad coincide con la esperada en .whd.\n');
end
for b = 1:nBursts_whd
    data.quality.flags(b).size_flag = size_flag(b);
end
%Graficar si se indica
if do_plot
    % Extraer bursts con tamaño incorrecto
    bad_size_idx = find(size_flag(1:minBursts));
    bad_size_burst_vec = zeros(numel(bad_size_idx),1);
    bad_size_burst_value = zeros(numel(bad_size_idx),1);
    for k = 1:numel(bad_size_idx)
        b = bad_size_idx(k);
        bad_size_burst_vec(k) = data.whd(b).burst_counter;
        bad_size_burst_value(k) = data.wad(b).nSamples;
    end
    burst_counter_vec   = zeros(size(data.whd));
    expected_vec        = zeros(size(data.whd));
    actual_vec          = zeros(size(data.whd));
    for i = 1:minBursts
        burst_counter_vec(i) = data.whd(i).burst_counter;
        expected_vec(i) = data.whd(i).n_wave_records;
        actual_vec(i) = data.wad(i).nSamples;
    end
    figure('Name','Verificación de cantidad de muestras','Color','w')
    title('Verificación de número de muestras por burst')
    hold on
    xlabel('Burst')
    ylabel('Número de muestras')
    ylim([0, max(expected_vec)+200])
    plot(burst_counter_vec, expected_vec, '-', 'DisplayName', 'Esperado (.whd)')
    plot(burst_counter_vec, actual_vec, '-', 'DisplayName', 'Actual (.wad)')
    scatter(bad_size_burst_vec, bad_size_burst_value, 10, 'filled', 'r', 'DisplayName', 'Burst marcado')
    hold off
    legend
    grid on
    if ~isempty(save_plot_dir)
        saveas(gca, fullfile(save_plot_dir, 'verificacion_cantidad_muestras'), 'png')
    end
end

% Verificación temporal
if has_time
    fprintf('\nVerificando existencia de desplazamientos temporales en bursts...\n')
    time_mismatch = false;
    for b = 1:minBursts
        t_whd = data.whd(b).datetime;
        t_wad = data.wad(b).datetime(1);
        dt_seconds = abs(seconds(t_wad - t_whd));
        if dt_seconds > 1   % tolerancia de 1 segundo
            warning(['\tBurst %d: diferencia temporal entre .whd y .wad = %.2f s ' ...
                     '(whd: %s | wad: %s)\n'], ...
                     b, dt_seconds, string(t_whd), string(t_wad));
            time_mismatch = true;
        end
    end
    if ~time_mismatch
        fprintf('\tVerificación temporal OK: todos los bursts están alineados.\n');
    end
else
    fprintf('\nVerificación temporal omitida: el archivo .wad no contiene tiempo.\n')
end



%% Verificación de calidad de los datos #2
%
% Verificaciones realizadas:

fprintf('\n-------------------          Verificación de orientación de los datos (Heave, Pitch y Roll)         -------------------\n');

fprintf('\nLímites establecidos:\n')
fprintf('\t-Pitch máximo: %d °\n', pitch_limit)
fprintf('\t-Roll máximo: %d °\n', roll_limit)
fprintf('\t-Cambio máximo en heading: %d °\n', heading_jump_limit)
fprintf('\t-Cambio máximo en tilt (pitch/roll): %d °\n\n', tilt_jump_limit)

heading = [data.whd.heading_deg];
pitch   = [data.whd.pitch_deg];
roll    = [data.whd.roll_deg];


orientation_flag = false(nBursts_whd,1);

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
for b = 1:nBursts_whd
    data.quality.flags(b).orientation_flag = orientation_flag(b);
    if orientation_flag(b)
        fprintf('Burst %d presenta problemas de orientación\n', b)
    end
end

fprintf('\nResumen: %d bursts marcados como sospechosos.\n', ...
    sum(orientation_flag));

if do_plot
    burst_counter_vec = [data.whd.burst_counter];

    % Recalcular diferencias para graficar
    d_heading = abs(diff(heading));
    d_heading = min(d_heading, 360 - d_heading); % corregir wrapping
    d_pitch   = abs(diff(pitch));
    d_roll    = abs(diff(roll));

    % Para alinear con bursts
    d_heading_plot = [NaN, d_heading];
    d_pitch_plot   = [NaN, d_pitch];
    d_roll_plot    = [NaN, d_roll];

    figure('Name','Verificación de orientación','Color','w')

    % --- Subgráfico 1: valores absolutos ---
    subplot(2,1,1)
    hold on
    title('Verificación de orientación: valores absolutos')
    xlabel('Burst')
    ylabel('Ángulo (°)')

    plot(burst_counter_vec, heading, '-', 'DisplayName', 'Heading')
    plot(burst_counter_vec, pitch, '-', 'DisplayName', 'Pitch')
    plot(burst_counter_vec, roll, '-', 'DisplayName', 'Roll')

    yline(pitch_limit, '--', 'DisplayName', 'Límite pitch')
    yline(-pitch_limit, '--', 'HandleVisibility','off')
    yline(roll_limit, ':', 'DisplayName', 'Límite roll')
    yline(-roll_limit, ':', 'HandleVisibility','off')

    % Bursts malos
    scatter(burst_counter_vec(orientation_flag), ...
            pitch(orientation_flag), 40, 'r', 'filled', ...
            'DisplayName', 'Burst sospechoso')
    scatter(burst_counter_vec(orientation_flag), ...
            roll(orientation_flag), 40, 'r', 'filled', ...
            'HandleVisibility','off')

    hold off
    legend('Location','best')
    grid on

    % --- Subgráfico 2: saltos entre bursts ---
    subplot(2,1,2)
    hold on
    title('Verificación de orientación: cambios entre bursts')
    xlabel('Burst')
    ylabel('\Delta ángulo (°)')

    plot(burst_counter_vec, d_heading_plot, '-', 'DisplayName', '\Delta Heading')
    plot(burst_counter_vec, d_pitch_plot, '-', 'DisplayName', '\Delta Pitch')
    plot(burst_counter_vec, d_roll_plot, '-', 'DisplayName', '\Delta Roll')

    yline(heading_jump_limit, '--', 'DisplayName', 'Límite salto heading')
    yline(tilt_jump_limit, ':', 'DisplayName', 'Límite salto tilt')

    scatter(burst_counter_vec(orientation_flag), ...
            d_heading_plot(orientation_flag), 40, 'r', 'filled', ...
            'DisplayName', 'Burst marcado')
    scatter(burst_counter_vec(orientation_flag), ...
            d_pitch_plot(orientation_flag), 40, 'r', 'filled', ...
            'HandleVisibility','off')
    scatter(burst_counter_vec(orientation_flag), ...
            d_roll_plot(orientation_flag), 40, 'r', 'filled', ...
            'HandleVisibility','off')

    hold off
    legend('Location','best')
    grid on

    if ~isempty(save_plot_dir)
        saveas(gca, fullfile(save_plot_dir, 'verificacion_orientacion'), 'png')
    end
end



fprintf('\n-----------------------------------              Verificación de presión             ----------------------------------\n');

mean_pressure = NaN(nBursts_whd,1);

for b = 1:minBursts
    mean_pressure(b) = mean(data.wad(b).pressure_dbar);
end

median_pressure = median(mean_pressure, 'omitnan');

fprintf('\nLímites establecidos:\n')
fprintf('\t-Presión mínima: %d dbar\n', min_pressure_limit)
fprintf('\t-Diferencia de presión respecto a la mediana: %d dbar\n\n', pressure_drop_limit)

bad_pressure = isnan(mean_pressure) | ...
               mean_pressure < min_pressure_limit | ...
               abs(mean_pressure - median_pressure) > pressure_drop_limit;

for b = 1:nBursts_whd
    data.quality.flags(b).pressure_flag = bad_pressure(b);
    if bad_pressure(b)
        fprintf('Burst %d presenta problemas de presión\n', b)
    end
end

fprintf('\nResumen: %d bursts marcados como sospechosos.\n', ...
    sum(bad_pressure));

if do_plot
    burst_counter_vec = [data.whd.burst_counter];

    figure('Name','Verificación de presión','Color','w')
    hold on
    title('Verificación de presión por burst')
    xlabel('Burst')
    ylabel('Presión media (dbar)')

    plot(burst_counter_vec, mean_pressure, '-', 'DisplayName', 'Presión media')

    yline(min_pressure_limit, '--', 'DisplayName', 'Presión mínima')
    yline(median_pressure, '-', 'DisplayName', 'Mediana')
    yline(median_pressure + pressure_drop_limit, ':', ...
        'DisplayName', 'Mediana + límite')
    yline(median_pressure - pressure_drop_limit, ':', ...
        'DisplayName', 'Mediana - límite')

    scatter(burst_counter_vec(bad_pressure), ...
            mean_pressure(bad_pressure), ...
            40, 'r', 'filled', ...
            'DisplayName', 'Burst marcado')

    hold off
    legend('Location','best')
    grid on

    if ~isempty(save_plot_dir)
        saveas(gca, fullfile(save_plot_dir, 'verificacion_presion'), 'png')
    end
end

%% Resumen

fprintf('\n----------------------------------              Resumen de verificaciones             ---------------------------------\n');

samples_flag = [data.quality.flags.samples_flag]';
size_flag        = [data.quality.flags.size_flag]';
orientation_flag = [data.quality.flags.orientation_flag]';
pressure_flag    = [data.quality.flags.pressure_flag]';

bad_bursts = samples_flag | size_flag | orientation_flag | pressure_flag;

fprintf('\nTotal bursts malos detectados: %d de %d\n', ...
    sum(bad_bursts), length(bad_bursts));



qc_summary = struct();

qc_summary.total_bursts = nBursts_whd;

qc_summary.samples_flag_count     = sum(samples_flag);
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
qc_summary.time_start = data.whd(1).datetime;
qc_summary.time_end   = data.whd(end).datetime;

% Rango temporal de bursts malos (si existen)
if any(bad_bursts)
    qc_summary.bad_datetimes = ...
        [data.whd(bad_bursts).datetime];
else
    qc_summary.bad_datetimes = datetime.empty(1,0);
end

% Guardar en struct principal
data.quality.summary = qc_summary;

% Guardar numero de mediciones de olas
data.hdr.general.Number_of_wave_measurements = nBursts_whd;

data.cleaning_applied = false;

fprintf('\n========================================================================================================================\n');
end

