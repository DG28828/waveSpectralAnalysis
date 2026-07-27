function data_clean = wsa_aquadopp_clean(data_in, varargin)
%wsa_aquadopp_clean - limpia datos AQUADOPP a partir de flags de calidad.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 27/07/2026
% Fecha de modificación: 27/07/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

p = inputParser;

addRequired(p, 'data_in');

addParameter(p, 'man', false, @(x) islogical(x) && isscalar(x));      %Flag para limpieza manual - falso por defecto
addParameter(p, 'clean_idx', [], @(x) isnumeric(x) && isvector(x));   %Indices de estados de mar a limpiar - ninguno por defecto

parse(p, data_in, varargin{:});

man = p.Results.man;
clean_idx = p.Results.clean_idx;

%% Si la entrada es raw.nc, reconstruir struct data

if ischar(data_in) || isstring(data_in)
    ncfile = char(data_in);

    if ~isfile(ncfile)
        error('El archivo netCDF no existe: %s', ncfile);
    end

    fprintf('\nReconstruyendo struct data desde netCDF:\n%s\n', ncfile);
    data = wsa_aquadopp_nc_read_raw(ncfile);

elseif isstruct(data_in)
    data = data_in;

else
    error('La entrada debe ser un struct data o la ruta a un archivo raw.nc.');
end


%% Verificaciones iniciales

fprintf('\n\n=========================================================================================================================\n');
fprintf('===========================================          Limpieza de AQUADOPP         ===========================================\n');
fprintf('\nLimpiar datos de archivos crudos de AQUADOPP.\n');

% Verificar que el struct de entrada haya sido generado por wsa_aquadopp_read.m
if ~isfield(data, 'dia') || ~isfield(data, 'dia_info')
    error('El struct no contiene los campos data.dia y data.dia_info.');
end

if ~isfield(data, 'cleaning_status')
    data.cleaning_status = false;
end

%Verificar si ya se hizo una limpieza
if data.cleaning_status
    error('Ya se ha realizado una limpieza previa de los datos ingresados, ingrese datos crudos.')
end


nBurstRaw = numel(data.dia);
if numel(data.dia_info) ~= nBurstRaw
    error('data.dia contiene %d ráfagas y data.dia_info contiene %d.', nBurstRaw, numel(data.dia_info));
end

%% Limpiar datos (por defecto se limpia según control de calidad de wsa_awac_read)

if ~man
    fprintf('\nModo de limpieza: automático.\n\n')
    if ~isfield(data, 'quality') || ~isfield(data.quality, 'summary') || ~isfield(data.quality.summary, 'bad_bursts')
        error('No se encontró data.quality.summary.bad_bursts para realizar la limpieza automática.');
    end
    bad_bursts = logical(data.quality.summary.bad_bursts(:));
else
    fprintf('\nComenzando limpieza de datos.\n\n')
    fprintf('\nModo de limpieza: manual.\n')
    if isempty(clean_idx)
        error('El modo manual de limpieza requiere que se indique los índices (bursts) a limpiar, mediante el vector clean_idx');
    end

    clean_idx = unique(clean_idx(:));

    if any(~isfinite(clean_idx)) || any(clean_idx ~= fix(clean_idx)) || any(clean_idx < 1) || any(clean_idx > nBurstRaw)
        error('clean_idx contiene índices inválidos.');
    end
    bad_bursts = false(nBurstRaw,1);
    bad_bursts(clean_idx) = true;

end

if numel(bad_bursts) ~= nBurstRaw
    error('La máscara de limpieza contiene %d elementos, pero existen %d ráfagas diagnósticas.', ...
        numel(bad_bursts), nBurstRaw);
end

good_idx = ~bad_bursts;

data_clean = data;

data_clean.dia = data.dia(good_idx);
data_clean.dia_info = data.dia_info(good_idx);

% data.dat se conserva porque no corresponde uno a uno con data.dia.
data_clean.dat = data.dat;

%% Información de limpieza

data_clean.cleaning = struct();

data_clean.cleaning.Number_of_wave_measurements = sum(good_idx);
data_clean.cleaning.Number_of_diagnostic_bursts = sum(good_idx);
data_clean.cleaning.Number_of_raw_wave_measurements = nBurstRaw;
data_clean.cleaning.Number_of_raw_diagnostic_bursts = nBurstRaw;
data_clean.cleaning.time_start = data_clean.dia_info(1).datetime;
data_clean.cleaning.time_end = data_clean.dia_info(end).end_datetime;

data_clean.cleaning.is_bad_burst = bad_bursts;
data_clean.cleaning.bad_indices_raw = find(bad_bursts);
data_clean.cleaning.good_indices_raw = find(good_idx);

data_clean.cleaning_status = true;

%Indicar tipo de limpieza realizada
if ~man
    data_clean.cleaning.cleaning_type = 'automatic';
else
    data_clean.cleaning.cleaning_type = 'manual';
end

fprintf('Se eliminaron %d bursts. Quedan %d bursts válidos.\n', sum(bad_bursts), sum(good_idx));

fprintf('\n========================================================================================================================\n');
end