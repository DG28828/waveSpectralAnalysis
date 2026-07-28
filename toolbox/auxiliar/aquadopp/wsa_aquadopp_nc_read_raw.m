function data = wsa_aquadopp_nc_read_raw(ncfile)
%wsa_aquadopp_nc_read_raw - reconstruye datos AQUADOPP desde raw.nc.

%% Verificar instrumento

instrument_type = string( ...
    read_att_safe(ncfile,'/','instrument_type',""));

if ~strcmpi(instrument_type,"AQUADOPP")
    error(['El archivo netCDF no corresponde a un AQUADOPP. ' ...
           'instrument_type = "%s".'], instrument_type);
end

%% Leer variables comunes

time_posix = ncread(ncfile,'time');

time_dt = datetime( time_posix, 'ConvertFrom','posixtime', 'TimeZone','UTC');

time_dt.TimeZone = '';

n_wave_records = ncread(ncfile,'n_wave_records');
battery_voltage = ncread(ncfile,'battery_voltage');
sound_speed = ncread(ncfile,'sound_speed');
heading = ncread(ncfile,'heading');
pitch = ncread(ncfile,'pitch');
roll = ncread(ncfile,'roll');
tilt = ncread(ncfile,'tilt');
min_pressure = ncread(ncfile,'min_pressure');
max_pressure = ncread(ncfile,'max_pressure');
temperature = ncread(ncfile,'temperature');

pressure = ncread(ncfile,'pressure');
velocity_beams = ncread(ncfile,'velocity_beams');
amplitude = ncread(ncfile,'amplitude');
analog_input = ncread(ncfile,'analog_input');

error_code = read_var_safe(ncfile,'error_code', nan(size(pressure)));

status_code = read_var_safe(ncfile,'status_code', nan(size(pressure)));

%% Dimensiones

nBurst = numel(time_posix);
nSamples = size(pressure,1);

sampling_rate_Hz = read_att_safe(ncfile,'/','sampling_rate_Hz',NaN);
burst_duration_s = read_att_safe(ncfile,'/','burst_duration_s',NaN);

%% HDR mínimo

data = struct();

data.hdr.general.Number_of_diagnostic_bursts = nBurst;
data.hdr.general.Time_of_first_measurement = time_dt(1);
data.hdr.general.Time_of_last_measurement = time_dt(end);
data.hdr.general.Deployment_duration = time_dt(end)-time_dt(1);

data.hdr.setup.Diagnostics_Number_of_samples = nSamples;
data.hdr.setup.Diagnostics_Sampling_rate_Hz = sampling_rate_Hz;
data.hdr.setup.Diagnostics_burst_duration_s = burst_duration_s;
data.hdr.setup.Coordinate_system = string(read_att_safe(ncfile,'/','Coordinate_system',""));

data.hdr.hardware_configuration.Serial_number = string(read_att_safe(ncfile,'/','instrument_serial',""));
data.hdr.head_configuration.Serial_number = string(read_att_safe(ncfile,'/','head_serial',""));
data.hdr.head_configuration.Transformation_matrix = ncread(ncfile,'transformation_matrix');

data.hdr.file_paths.nc = ncfile;

%% Reconstruir dia_info y dia

data.dia_info(nBurst,1) = struct();
data.dia(nBurst,1) = struct();

for b = 1:nBurst

    data.dia_info(b).burst_index = b;
    data.dia_info(b).datetime = time_dt(b);

    if isfinite(sampling_rate_Hz) && sampling_rate_Hz > 0
        data.dia_info(b).end_datetime = time_dt(b) + seconds((nSamples-1)/sampling_rate_Hz);
    else
        data.dia_info(b).end_datetime = NaT;
    end

    data.dia_info(b).n_diagnostic_records = n_wave_records(b);
    data.dia_info(b).battery_voltage_V = battery_voltage(b);
    data.dia_info(b).sound_speed_ms = sound_speed(b);

    data.dia_info(b).heading_deg = heading(b);
    data.dia_info(b).pitch_deg = pitch(b);
    data.dia_info(b).roll_deg = roll(b);
    data.dia_info(b).tilt_deg = tilt(b);

    data.dia_info(b).min_pressure_dbar = min_pressure(b);
    data.dia_info(b).max_pressure_dbar = max_pressure(b);
    data.dia_info(b).mean_pressure_dbar = mean(pressure(:,b),'omitnan');
    data.dia_info(b).temperature_degC = temperature(b);

    data.dia(b).datetime = data.dia_info(b).datetime + seconds((0:nSamples-1)'/sampling_rate_Hz);

    data.dia(b).pressure_dbar = pressure(:,b);
    data.dia(b).beam_velocity_ms = squeeze(velocity_beams(:,:,b));

    data.dia(b).amplitude = squeeze(amplitude(:,:,b));

    data.dia(b).analog1 = squeeze(analog_input(:,1,b));
    data.dia(b).analog2 = squeeze(analog_input(:,2,b));

    data.dia(b).error_code = error_code(:,b);
    data.dia(b).status_code = status_code(:,b);

    data.dia(b).nSamples = nSamples;
end

function value = read_var_safe(ncfile,varname,default_value)

try
    value = ncread(ncfile,varname);
catch
    value = default_value;
end

end


function value = read_att_safe(ncfile,location,attname,default_value)

try
    value = ncreadatt(ncfile,location,attname);
catch
    value = default_value;
end

end


end