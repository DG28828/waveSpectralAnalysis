function wsa_awac_nc_write(data, ncfile, varargin)
%wsa_write_netcdf_level1 Exporta un struct de campaña AWAC a netCDF.
%
%   wsa_write_netcdf_level1(data, ncfile)
%
%   data   : struct tipo data_clean
%   ncfile : ruta completa del archivo .nc a crear
%
%   Esta función asume una estructura similar a la del .mat de ejemplo:
%   data.hdr
%   data.whd(1:nBurst)
%   data.wad(1:nBurst)
%   data.quality
%
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
site_name_default       = "";
campaign_name_default   = "";
overwrite_default       = true;

%Input parser
p = inputParser;

%%%%%% Parámetros requeridos %%%%%%
addRequired(p, 'data');
addRequired(p, 'ncfile');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Parámetros opcionales %%%%%%
 addParameter(p, 'site_name', site_name_default, @(x) ischar(x) || isstring(x));
 addParameter(p, 'campaign_name', campaign_name_default, @(x) ischar(x) || isstring(x));
 addParameter(p, 'overwrite', overwrite_default, @(x) islogical(x) && isscalar(x));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse(p, data, ncfile, varargin{:});

%%%%%%%    Resultados     %%%%%%%%
site_name       = string(p.Results.site_name);
campaign_name   = string(p.Results.campaign_name);
overwrite       = p.Results.overwrite;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Verificaciones iniciales

%Verificar existencia de archivo y sobreescritura
if exist(ncfile, 'file')
    if overwrite
        delete(ncfile);
    else
        error('El archivo netcdf ya existe: %s', ncfile);
    end
end

%Verificar existencia de directorio
outdir = fileparts(ncfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%Verificar existencia de campos whd y wad en struct de entrada
if ~isfield(data, 'whd') || ~isfield(data, 'wad')
    error('El struct de entrada no contiene whd, wad o ambos.');
end

%Verificar que whd no este vacio
nBurst = numel(data.whd);
if nBurst == 0
    error('data.whd está vacío.');
end

%Verificar que whd y wad tenga la misma cantidad de bursts
nBurstData = numel(data.wad);
if nBurstData ~= nBurst
    error('whd (%d) y wad (%d) no tienen la misma cantidad de bursts.', ...
        nBurst, nBurstData);
end

%% Declarar variables

nSamples = data.hdr.setup.Wave_Number_of_samples;
nVels = size(data.wad(1).velocity_ms, 2);
nAst = size(data.wad(1).ast_distance_m, 2);
nNoiseBeams = numel(data.whd(1).noise_amp_beams);

% Variables de whd
time = nan(nBurst,1);
burst_counter   = nan(nBurst,1);
n_wave_records  = nan(nBurst,1);
cell_position_m = nan(nBurst,1);
battery_voltage_V = nan(nBurst,1);
sound_speed_ms  = nan(nBurst,1);
heading_deg     = nan(nBurst,1);
pitch_deg       = nan(nBurst,1);
roll_deg        = nan(nBurst,1);
min_pressure_dbar = nan(nBurst,1);
max_pressure_dbar = nan(nBurst,1);
temperature_degC = nan(nBurst,1);
cell_size_m     = nan(nBurst,1);
noise_amp_beams = nan(nNoiseBeams, nBurst);
ast_window_start_m  = nan(nBurst,1);
ast_window_size_m   = nan(nBurst,1);
ast_window_offset_m = nan(nBurst,1);

% Variables de wad
pressure_dbar = nan(nSamples, nBurst);
ast_distance_m = nan(nSamples, nAst, nBurst);
ast_quality = zeros(nSamples, nBurst, 'uint8');
analog_input = zeros(nSamples, nBurst, 'uint8');
velocity_ms = nan(nSamples, nVels, nBurst);
amplitude = zeros(nSamples, nVels, nBurst, 'uint8');

% Variables de control de calidad
samples_flag = nan(nBurst,1);
size_flag = nan(nBurst,1);
orientation_flag = nan(nBurst,1);
pressure_flag = nan(nBurst,1);
is_bad_burst = zeros(nBurst,1,'uint8');

%% Extraer datos

%Extraer datos de whd y wad
for i = 1:nBurst
    wi = data.whd(i);
    wd = data.wad(i);
    
    %Información de whd
    time(i) = wsa_datetime2posix(wi.datetime); % Tiempo: guardar como segundos POSIX
    burst_counter(i)        = wsa_get_struct_field(wi, 'burst_counter');
    n_wave_records(i)       = wsa_get_struct_field(wi, 'n_wave_records');
    cell_position_m(i)      = wsa_get_struct_field(wi, 'cell_position_m');
    battery_voltage_V(i)    = wsa_get_struct_field(wi, 'battery_voltage_V');
    sound_speed_ms(i)       = wsa_get_struct_field(wi, 'sound_speed_ms');
    heading_deg(i)          = wsa_get_struct_field(wi, 'heading_deg');
    pitch_deg(i)            = wsa_get_struct_field(wi, 'pitch_deg');
    roll_deg(i)             = wsa_get_struct_field(wi, 'roll_deg');
    min_pressure_dbar(i)    = wsa_get_struct_field(wi, 'min_pressure_dbar');
    max_pressure_dbar(i)    = wsa_get_struct_field(wi, 'max_pressure_dbar');
    temperature_degC(i)     = wsa_get_struct_field(wi, 'temperature_degC');
    cell_size_m(i)          = wsa_get_struct_field(wi, 'cell_size_m');
    ast_window_start_m(i)   = wsa_get_struct_field(wi, 'ast_window_start_m');
    ast_window_size_m(i)    = wsa_get_struct_field(wi, 'ast_window_size_m');
    ast_window_offset_m(i)  = wsa_get_struct_field(wi, 'ast_window_offset_m');
    tmp_noise               = wsa_get_struct_field(wi, 'noise_amp_beams');
    if ~isempty(tmp_noise)
        noise_amp_beams(:,i) = double(tmp_noise(:));
    end
    
    %Información de wad
    % pressure_dbar
    tmp_pressure = double(wd.pressure_dbar(:));
    nAvail = min(nSamples, numel(tmp_pressure));
    pressure_dbar(1:nAvail, i) = tmp_pressure(1:nAvail);
    
    % ast_distance_m
    tmp_ast = double(wd.ast_distance_m);
    [nr, nc] = size(tmp_ast);
    nr = min(nSamples, nr);
    nc = min(nAst, nc);
    ast_distance_m(1:nr, 1:nc, i) = tmp_ast(1:nr, 1:nc);
    
    % ast_quality
    tmp_astq = uint8(wd.ast_quality(:));
    nAvail = min(nSamples, numel(tmp_astq));
    ast_quality(1:nAvail, i) = tmp_astq(1:nAvail);
    
    % analog_input
    tmp_ai = uint8(wd.analog_input(:));
    nAvail = min(nSamples, numel(tmp_ai));
    analog_input(1:nAvail, i) = tmp_ai(1:nAvail);
    
    % velocity_ms
    tmp_vel = double(wd.velocity_ms);
    [nr, nc] = size(tmp_vel);
    nr = min(nSamples, nr);
    nc = min(nVels, nc);
    velocity_ms(1:nr, 1:nc, i) = tmp_vel(1:nr, 1:nc);
    
    % amplitude
    tmp_amp = uint8(wd.amplitude);
    [nr, nc] = size(tmp_amp);
    nr = min(nSamples, nr);
    nc = min(nVels, nc);
    amplitude(1:nr, 1:nc, i) = tmp_amp(1:nr, 1:nc);
end

%Extraer datos de control de calidad   (REVISAR ESTO - flags es mayor que cleaned size)
if isfield(data, 'quality') && isfield(data.quality, 'flags')
    nQC = min(numel(data.quality.flags), nBurst);

    for i = 1:nQC
        qf = data.quality.flags(i);
        samples_flag(i)     = wsa_get_struct_field(qf, 'samples_flag');
        size_flag(i)        = wsa_get_struct_field(qf, 'size_flag');
        orientation_flag(i) = wsa_get_struct_field(qf, 'orientation_flag');
        pressure_flag(i)    = wsa_get_struct_field(qf, 'pressure_flag');
    end
end

if isfield(data, 'quality') && isfield(data.quality, 'summary')
    if isfield(data.quality.summary, 'bad_indices')
        bad_idx = data.quality.summary.bad_indices;
        bad_idx = double(bad_idx(:));
        bad_idx = bad_idx(~isnan(bad_idx));
        bad_idx = bad_idx(bad_idx >= 1 & bad_idx <= nBurst);
        is_bad_burst(bad_idx) = 1;
    end
end

%% Crear dimensiones y variables para netCDF

%Variables de 1 dimensión por burst
wsa_nc_create_var( ...
                   ncfile, ...                                              %ncfile
                  'time', ...                                               %varname
                  {'burst', nBurst}, ...                                    %dims
                  'double', ...                                             %datatype
                  'units', 'seconds since 1970-01-01 00:00:00 UTC', ...     %varargin1, value (unidad)
                  'long_name', 'burst time' ...                             %varargin2, value (nombre largo)
                  );

% Variables 1D: nombre, valor, tipo de dato, unidad
vars1d = {
    'burst_counter',        burst_counter,      'double', 'count';
    'n_wave_records',       n_wave_records,     'double', 'count';
    'cell_position_m',      cell_position_m,    'double', 'm';
    'battery_voltage_V',    battery_voltage_V,  'double', 'V';
    'sound_speed_ms',       sound_speed_ms,     'double', 'm s-1';
    'heading_deg',          heading_deg,        'double', 'degree';
    'pitch_deg',            pitch_deg,          'double', 'degree';
    'roll_deg',             roll_deg,           'double', 'degree';
    'min_pressure_dbar',    min_pressure_dbar,  'double', 'dbar';
    'max_pressure_dbar',    max_pressure_dbar,  'double', 'dbar';
    'temperature_degC',     temperature_degC,   'double', 'degree_C';
    'cell_size_m',          cell_size_m,        'double', 'm';
    'ast_window_start_m',   ast_window_start_m, 'double', 'm';
    'ast_window_size_m',    ast_window_size_m,  'double', 'm';
    'ast_window_offset_m',  ast_window_offset_m,'double', 'm';
    'samples_flag',         samples_flag,       'double', '1';
    'size_flag',            size_flag,          'double', '1';
    'orientation_flag',     orientation_flag,   'double', '1';
    'pressure_flag',        pressure_flag,      'double', '1';
    'is_bad_burst',         is_bad_burst,       'uint8', '1';
    };
for k = 1:size(vars1d,1)
    name  = vars1d{k,1};
    dtype = vars1d{k,3};
    units = vars1d{k,4};
    wsa_nc_create_var( ...
                       ncfile, ...                  %ncfile
                       name, ...                    %varname
                       {'burst', nBurst}, ...       %dims
                       dtype, ...                   %datatype
                       'units', units, ...          %varargin1, value (unidad)
                       'long_name', name ...        %varargin2, value (nombre_largo)
                        );
end


%Variables 2D

% noise_amp_beams(beam_for_noise, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'noise_amp_beams', ...
                  {'beam_for_noise', nNoiseBeams, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'count', ...
                  'long_name', 'noise amplitude beams' ...
                  );

% pressure(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'pressure_dbar', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'dbar', ...
                  'long_name', 'pressure' ...
                  );

% ast_distance(sample, ast_measurement, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'ast_distance_m', ...
                  {'sample', nSamples, 'ast_measurement', nAst, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'm', 'long_name', ...
                  'ast distance' ...
                  );

% ast_quality(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'ast_quality', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'uint8', ...
                  'units', '1', ...
                  'long_name', 'ast quality' ...
                  );

% analog_input(sample, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'analog_input', ...
                  {'sample', nSamples, 'burst', nBurst}, ...
                  'uint8', ...
                  'units', 'count', ...
                  'long_name', 'analog input' ...
                  );

% velocity(sample, beam, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'velocity_ms', ...
                  {'sample', nSamples, 'beam', nVels, 'burst', nBurst}, ...
                  'double', ...
                  'units', 'm s-1', ...
                  'long_name', 'orbital velocity' ...
                  );

% amplitude(sample, beam, burst)
wsa_nc_create_var( ...
                  ncfile, ...
                  'amplitude', ...
                  {'sample', nSamples, 'beam', nVels, 'burst', nBurst}, ...
                  'uint8', ...
                  'units', 'count', ...
                  'long_name', 'signal amplitude' ...
                  );

%% Escribir datos

ncwrite(ncfile, 'time', time);
for k = 1:size(vars1d,1)
    name = vars1d{k,1};
    val  = vars1d{k,2};
    if strcmp(vars1d{k,3}, 'uint8')
        ncwrite(ncfile, name, uint8(val));
    else
        ncwrite(ncfile, name, double(val));
    end
end

ncwrite(ncfile, 'noise_amp_beams', noise_amp_beams);
ncwrite(ncfile, 'pressure_dbar', pressure_dbar);
ncwrite(ncfile, 'ast_distance_m', ast_distance_m);
ncwrite(ncfile, 'ast_quality', ast_quality);
ncwrite(ncfile, 'analog_input', analog_input);
ncwrite(ncfile, 'velocity_ms', velocity_ms);
ncwrite(ncfile, 'amplitude', amplitude);

%% Atributos globales

ncwriteatt(ncfile, '/', 'title', 'AWAC campaign data');
ncwriteatt(ncfile, '/', 'site_name', char(site_name));
ncwriteatt(ncfile, '/', 'campaign_name', char(campaign_name));

ncwriteatt(ncfile, '/', 'source', 'MATLAB WSA toolbox');
ncwriteatt(ncfile, '/', 'cleaning_applied', double(data.cleaning_applied));

if isfield(data, 'cleaning')
    ncwriteatt(ncfile, '/', 'cleaning_type', char(string(data.cleaning.cleaning_type)));
else
    ncwriteatt(ncfile, '/', 'cleaning_type', 'cleaning not applied');
end

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

if isfield(data, 'cleaning')
    ncwriteatt(ncfile, '/', 'Number_of_wave_measurements', double(data.cleaning.Number_of_wave_measurements));
else
    ncwriteatt(ncfile, '/', 'Number_of_wave_measurements', char(string(data.hdr.general.Number_of_wave_measurements)));
end


if isfield(data, 'hdr')
    gi = data.hdr;

    if isfield(gi, 'setup') && isfield(gi.setup, 'Wave_Sampling_rate_Hz')
        ncwriteatt(ncfile, '/', 'wave_sampling_rate_Hz', double(gi.setup.Wave_Sampling_rate_Hz));
    end

    if isfield(gi, 'setup') && isfield(gi.setup, 'Wave_Number_of_samples')
        ncwriteatt(ncfile, '/', 'wave_number_of_samples', double(gi.setup.Wave_Number_of_samples));
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


end