function data = wsa_awac_nc_read_raw(ncfile)
%wsa_awac_nc_read_raw - Reconstruye struct data desde raw.nc de AWAC.

%% Verificar variables requeridas

req_vars = {
    'time'
    'burst_counter'
    'n_wave_records'
    'cell_position'
    'battery_voltage'
    'sound_speed'
    'heading'
    'pitch'
    'roll'
    'min_pressure'
    'max_pressure'
    'temperature'
    'cell_size'
    'ast_window_start'
    'ast_window_size'
    'ast_window_offset'
    'noise_amp_beams'
    'pressure'
    'ast'
    'ast_quality'
    'analog_input'
    'velocity_beams'
    'amplitude'
    'samples_flag'
    'size_flag'
    'orientation_flag'
    'pressure_flag'
    'is_bad_burst'
    'bad_tilt_flag'
    'warning_tilt_flag'
    'transformation_matrix'
    };

info = ncinfo(ncfile);
var_names = {info.Variables.Name};

missing = req_vars(~ismember(req_vars, var_names));
if ~isempty(missing)
    error(['El archivo netCDF no contiene todas las variables requeridas.\n' ...
           'Faltantes: %s'], strjoin(missing, ', '));
end

%% Leer variables

time_posix = ncread(ncfile, 'time');
time_dt = datetime(time_posix, ...
    'ConvertFrom', 'posixtime', ...
    'TimeZone', 'UTC');
time_dt.TimeZone = '';

burst_counter = ncread(ncfile, 'burst_counter');
n_wave_records = ncread(ncfile, 'n_wave_records');
cell_position = ncread(ncfile, 'cell_position');
battery_voltage = ncread(ncfile, 'battery_voltage');
sound_speed = ncread(ncfile, 'sound_speed');
heading = ncread(ncfile, 'heading');
pitch = ncread(ncfile, 'pitch');
roll = ncread(ncfile, 'roll');
min_pressure = ncread(ncfile, 'min_pressure');
max_pressure = ncread(ncfile, 'max_pressure');
temperature = ncread(ncfile, 'temperature');
cell_size = ncread(ncfile, 'cell_size');
ast_window_start = ncread(ncfile, 'ast_window_start');
ast_window_size = ncread(ncfile, 'ast_window_size');
ast_window_offset = ncread(ncfile, 'ast_window_offset');
noise_amp_beams = ncread(ncfile, 'noise_amp_beams');

pressure = ncread(ncfile, 'pressure');
ast = ncread(ncfile, 'ast');
ast_quality = ncread(ncfile, 'ast_quality');
analog_input = ncread(ncfile, 'analog_input');
velocity_beams = ncread(ncfile, 'velocity_beams');
amplitude = ncread(ncfile, 'amplitude');

samples_flag = logical(ncread(ncfile, 'samples_flag'));
size_flag = logical(ncread(ncfile, 'size_flag'));
orientation_flag = logical(ncread(ncfile, 'orientation_flag'));
pressure_flag = logical(ncread(ncfile, 'pressure_flag'));
is_bad_burst = logical(ncread(ncfile, 'is_bad_burst'));
bad_tilt_flag = logical(ncread(ncfile, 'bad_tilt_flag'));
warning_tilt_flag = logical(ncread(ncfile, 'warning_tilt_flag'));

transformation_matrix = ncread(ncfile, 'transformation_matrix');

nBurst = numel(time_posix);

%% Reconstruir hdr mínimo

data = struct();
data.hdr = struct();

data.hdr.general = struct();
data.hdr.general.Number_of_wave_measurements = nBurst;
data.hdr.general.Time_of_first_measurement = time_dt(1);
data.hdr.general.Time_of_last_measurement = time_dt(end);
data.hdr.general.Deployment_duration = time_dt(end) - time_dt(1);

data.hdr.setup = struct();
data.hdr.setup.Wave_Number_of_samples = read_att_safe(ncfile, '/', 'wave_number_of_samples', size(pressure, 1));
data.hdr.setup.Wave_Sampling_rate_Hz = read_att_safe(ncfile, '/', 'wave_sampling_rate_Hz', NaN);
data.hdr.setup.Coordinate_system = string(read_att_safe(ncfile, '/', 'Coordinate_system', ""));
data.hdr.setup.Blanking_distance_m = read_att_safe(ncfile, '/', 'Blanking_distance_m', NaN);
data.hdr.setup.Wave_burst_duration_s = read_att_safe(ncfile, '/', 'Wave_burst_duration_s', NaN);

data.hdr.hardware_configuration = struct();
data.hdr.hardware_configuration.Serial_number = string(read_att_safe(ncfile, '/', 'instrument_serial', ""));

data.hdr.head_configuration = struct();
data.hdr.head_configuration.Serial_number = string(read_att_safe(ncfile, '/', 'head_serial', ""));
data.hdr.head_configuration.Transformation_matrix = transformation_matrix;

data.hdr.file_paths = struct();
data.hdr.file_paths.nc = ncfile;

%% Reconstruir whd

data.whd(nBurst, 1) = struct();

for b = 1:nBurst
    data.whd(b).datetime = time_dt(b);
    data.whd(b).burst_counter = burst_counter(b);
    data.whd(b).n_wave_records = n_wave_records(b);
    data.whd(b).cell_position_m = cell_position(b);
    data.whd(b).battery_voltage_V = battery_voltage(b);
    data.whd(b).sound_speed_ms = sound_speed(b);
    data.whd(b).heading_deg = heading(b);
    data.whd(b).pitch_deg = pitch(b);
    data.whd(b).roll_deg = roll(b);
    data.whd(b).min_pressure_dbar = min_pressure(b);
    data.whd(b).max_pressure_dbar = max_pressure(b);
    data.whd(b).temperature_degC = temperature(b);
    data.whd(b).cell_size_m = cell_size(b);
    data.whd(b).noise_amp_beams = noise_amp_beams(:, b).';
    data.whd(b).ast_window_start_m = ast_window_start(b);
    data.whd(b).ast_window_size_m = ast_window_size(b);
    data.whd(b).ast_window_offset_m = ast_window_offset(b);
end

%% Reconstruir wad

data.wad(nBurst, 1) = struct();

for b = 1:nBurst
    data.wad(b).datetime = [];
    data.wad(b).burst_counter = burst_counter(b);

    data.wad(b).pressure_dbar = pressure(:, b);

    data.wad(b).ast_distance_m = squeeze(ast(:, :, b));

    data.wad(b).ast_quality = ast_quality(:, b);
    data.wad(b).analog_input = analog_input(:, b);

    data.wad(b).beam_velocity_ms = squeeze(velocity_beams(:, :, b));
    data.wad(b).amplitude = squeeze(amplitude(:, :, b));

    data.wad(b).nSamples = size(pressure, 1);
end

%% Reconstruir quality

data.quality = struct();
data.quality.flags(nBurst, 1) = struct();

for b = 1:nBurst
    data.quality.flags(b).samples_flag = samples_flag(b);
    data.quality.flags(b).size_flag = size_flag(b);
    data.quality.flags(b).orientation_flag = orientation_flag(b);
    data.quality.flags(b).pressure_flag = pressure_flag(b);
    data.quality.flags(b).bad_tilt_flag = bad_tilt_flag(b);
    data.quality.flags(b).warning_tilt_flag = warning_tilt_flag(b);
end

bad_bursts = is_bad_burst(:);

data.quality.summary = struct();
data.quality.summary.total_bursts = nBurst;
data.quality.summary.samples_flag_count = sum(samples_flag);
data.quality.summary.size_flag_count = sum(size_flag);
data.quality.summary.orientation_flag_count = sum(orientation_flag);
data.quality.summary.pressure_flag_count = sum(pressure_flag);
data.quality.summary.bad_tilt_flag_count = sum(bad_tilt_flag);
data.quality.summary.warning_tilt_flag_count = sum(warning_tilt_flag);
data.quality.summary.bad_bursts = bad_bursts;
data.quality.summary.total_bad_bursts = sum(bad_bursts);
data.quality.summary.total_good_bursts = sum(~bad_bursts);
data.quality.summary.percentage_bad = 100 * sum(bad_bursts) / nBurst;
data.quality.summary.bad_indices = find(bad_bursts);
data.quality.summary.good_indices = find(~bad_bursts);
data.quality.summary.time_start = time_dt(1);
data.quality.summary.time_end = time_dt(end);

if any(bad_bursts)
    data.quality.summary.bad_datetimes = time_dt(bad_bursts);
else
    data.quality.summary.bad_datetimes = datetime.empty(1, 0);
end

%% Flags generales

data.cleaning_status = logical(read_att_safe(ncfile, '/', 'cleaning_status', 0));
data.preprocessing_status = logical(read_att_safe(ncfile, '/', 'preprocessing_status', 0));

end


function val = read_att_safe(ncfile, location, attname, default_val)
%read_att_safe - Lee atributo netCDF si existe; si no, devuelve default.

try
    val = ncreadatt(ncfile, location, attname);
catch
    val = default_val;
end

end