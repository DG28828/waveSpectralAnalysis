function info = wsa_nc_preprocess(ncfile, varargin)
%wsa_nc_preprocess - preprocesa señales de oleaje guardadas en netCDF para instrumentos de medición.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 10/03/2026
% Fecha de modificación: 06/08/2026
% -------------------------------------------------------------------------
%% Manejo de entradas

p = inputParser;

addRequired(p, 'ncfile', @(x) ischar(x) || isstring(x));

addParameter(p, 'ast_corr_flag', true, @(x) islogical(x) && isscalar(x))
addParameter(p, 'filter_flag', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'IG_filter_flag', true, @(x) islogical(x) && isscalar(x));

parse(p, ncfile, varargin{:});

ast_corr_flag = p.Results.ast_corr_flag;
filter_flag = p.Results.filter_flag;
IG_filter_flag = p.Results.IG_filter_flag;

%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('====================================              Preprocesamiento de datos             ====================================\n');
fprintf('\nPreprocesar datos instrumentales almacenados en netCDF.\n');

%Verificar existencia de archivo netCDF
if ~isfile(ncfile)
    error('El archivo no existe: %s', ncfile)
end

% Identificar instrumento
instrument_type = upper(string(read_att_safe(ncfile, '/', 'instrument_type', "")));
if ~ismember(instrument_type, ["AWAC", "AQUADOPP", "RBR"])
    error(['El atributo global instrument_type no existe o no contiene ' ...
           'un instrumento compatible. Valor encontrado: "%s".'], ...
           instrument_type);
end
is_awac = instrument_type == "AWAC";
is_aquadopp = instrument_type == "AQUADOPP";
is_rbr = instrument_type == "RBR";

fprintf('\nInstrumento: %s.\n', instrument_type);

% Identificar sistema de coordenadas
coordinate_system = upper(string(read_att_safe(ncfile, '/', 'coordinate_system', "")));

fprintf('\nSistema de coordenadas configurado: %s.\n', coordinate_system);

%% Verificar variables requeridas

% Variables existentes
nc_info = ncinfo(ncfile);
nc_var_names = {nc_info.Variables.Name};

% Variables requeridas
required_vars = ["time"; "pressure"];

switch instrument_type
    case "AWAC"
        required_vars = [
            required_vars
            "ast"
            "velocity_beams"
            "transformation_matrix"
            "heading"
            "pitch"
            "roll"
            "cell_position"
        ];

    case "AQUADOPP"
        required_vars = [
            required_vars
            "velocity_beams"
        ];

        % Estos campos solamente son requeridos cuando se debe transformar desde BEAM.
        if coordinate_system == "BEAM"
            required_vars = [
                required_vars
                "transformation_matrix"
                "heading"
                "pitch"
                "roll"
            ];
        end

    case "RBR"
        % El RBR solamente requiere tiempo y presión.
end

missing_vars = required_vars(~ismember(required_vars, nc_var_names));

if ~isempty(missing_vars)
    error('El archivo no contiene todas las variables requeridas.\nInstrumento: %s\nVariables faltantes: %s', instrument_type, strjoin(missing_vars, ', '));
end

%% Leer atributos de disponibilidad de variables

pressure_available          = nc_variable_available(ncfile, 'pressure', nc_var_names);
ast_available               = nc_variable_available(ncfile, 'ast', nc_var_names);
velocity_available          = nc_variable_available(ncfile, 'velocity_beams', nc_var_names);
transformation_available    = nc_variable_available(ncfile, 'transformation_matrix', nc_var_names);
heading_available           = nc_variable_available( ncfile, 'heading', nc_var_names);
pitch_available             = nc_variable_available(ncfile, 'pitch', nc_var_names);
roll_available              = nc_variable_available(ncfile, 'roll', nc_var_names);

if is_rbr
    ast_available = false;
    velocity_available = false;
    transformation_available = false;
    heading_available = false;
    pitch_available = false;
    roll_available = false;
end

if ~pressure_available
    error('La variable pressure existe, pero no contiene datos disponibles.');
end

%% Extraer datos requeridas

time = ncread(ncfile, 'time');
pressure = ncread(ncfile, 'pressure');

nSamples = size(pressure, 1);
nBursts  = size(pressure, 2);

if numel(time) ~= nBursts
    error('La variable time contiene %d valores, pero pressure contiene %d bursts.', numel(time), nBursts);
end

time = time(:);

% Inicializar variables no comunes como no NaN, para que se rellenen con FillValue en caso de no leerse.
velocity_beams = nan(nSamples, 3, nBursts);
transformation_matrix = nan(3, 3);
heading = nan(nBursts, 1);
pitch = nan(nBursts, 1);
roll = nan(nBursts, 1);
ast = nan(nSamples, 2, nBursts);

if velocity_available
    velocity_beams = ncread(ncfile, 'velocity_beams');
    if size(velocity_beams,1) ~= nSamples || size(velocity_beams,2) ~= 3 || size(velocity_beams,3) ~= nBursts
        error('La variable velocity_beams debe tener dimensiones sample × 3 × burst.');
    end
end

if transformation_available
    transformation_matrix = ncread(ncfile, 'transformation_matrix');
end

if heading_available
    heading = ncread(ncfile, 'heading');
    heading = heading(:);
end

if pitch_available
    pitch = ncread(ncfile, 'pitch');
    pitch = pitch(:);
end

if roll_available
    roll = ncread(ncfile, 'roll');
    roll = roll(:);
end

if ast_available
    ast = double(ncread(ncfile, 'ast'));
    if size(ast,1) ~= nSamples || size(ast,2) ~= 2 || size(ast,3) ~= nBursts
        error('La variable ast debe tener dimensiones sample × 2 × burst.');
    end
end

%% Información adicional

sampling_rate = double(read_att_safe(ncfile, '/', 'sampling_rate_Hz', NaN));

number_of_samples_att = double(read_att_safe(ncfile, '/', 'number_of_samples', NaN));

mounting_height = double(read_att_safe(ncfile, '/', 'mounting_height_m', NaN));
blanking_distance = double(read_att_safe(ncfile, '/', 'blanking_distance_m', NaN));

cell_position = nan(nBursts, 1);
if is_awac
    cell_position = ncread(ncfile, 'cell_position');
elseif is_aquadopp
    cell_size = 0.75; %m
    fixed_cell_position = blanking_distance + 1.5*cell_size;
    cell_position = fixed_cell_position*ones(nBursts, 1);
elseif is_rbr
    %RBR no tiene celda de velocidad
    cell_position(:) = NaN;
end


if ~isfinite(sampling_rate) || sampling_rate <= 0
    error('El archivo no contiene una frecuencia de muestreo válida.');
end

if isfinite(number_of_samples_att) && ...
    number_of_samples_att ~= nSamples
    warning('El atributo number_of_samples indica %d muestras, pero la dimensión sample contiene %d. Se utilizará %d.', number_of_samples_att, nSamples, nSamples);
end

% Leer metadatos para RBR
atmospheric_pressure_dbar = double(read_att_safe(ncfile, '/', 'atmospheric_pressure_dbar', NaN));
rbr_density = double(read_att_safe(ncfile, '/', 'ruskin_density', NaN));
pressure_reference = lower(string(read_att_safe(ncfile, '/', 'pressure_reference', "")));

if is_rbr && isempty(mounting_height)
    warning('La campaña RBR no tiene mounting_height. La presión podrá preprocesarse, pero no será posible calcular h ni aplicar posteriormente la corrección espectral por presión.');
end

%% Estandarizar presión a presión manométrica

% Conservar la referencia original.
pressure_reference_original = lower(string(read_att_safe(ncfile, '/', 'pressure_reference_original', pressure_reference)));

pressure_atmospheric_correction_applied = false;
pressure_atmospheric_correction_dbar = 0;

if is_rbr

    switch pressure_reference

        case {"absolute", "abs"}

            if ~isfinite(atmospheric_pressure_dbar)
                error('La presión del RBR está indicada como absoluta, pero no se dispone de una presión atmosférica válida para convertirla a presión manométrica.');
            end

            % Conversión de presión absoluta a manométrica.
            pressure = pressure - atmospheric_pressure_dbar;

            pressure_reference = "manometric";

            pressure_atmospheric_correction_applied = true;

            pressure_atmospheric_correction_dbar = atmospheric_pressure_dbar;

            fprintf('\nPresión RBR convertida de absoluta a manométrica utilizando %.6g dbar de presión atmosférica.\n', atmospheric_pressure_dbar);

        case {"gauge", "manometric", "manometrica"}

            % La presión ya se encuentra en la referencia estándar.
            pressure_reference = "manometric";

            fprintf('\nLa presión del RBR ya se encuentra indicada como manométrica. No se aplicó corrección.\n');

        otherwise
            error('No fue posible interpretar la referencia de presión del RBR. Valor encontrado: "%s".', pressure_reference);
    end

else

    % Se asume que AWAC y AQUADOPP entregan presión manométrica.
    pressure_reference_original = "manometric";
    pressure_reference = "manometric";
end

% Sobreescribir presión
write_nc_variable( ...
    ncfile, ...
    'pressure', ...
    pressure, ...
    {'sample', nSamples, 'burst', nBursts}, ...
    'units', 'dbar', ...
    'long_name', 'manometric pressure', ...
    'pressure_reference', 'manometric', ...
    'description', 'Presión. Para RBR: la presión absoluta es convertida a presión manométrica restando la presión atmosférica guardada en los metadatos.');


% Conversión de presión mínima y máxima
if is_rbr

    nc_var_names_string = string(nc_var_names);

    if ismember("min_pressure", nc_var_names_string)

        min_pressure = double(ncread(ncfile, 'min_pressure'));

        if pressure_atmospheric_correction_applied
            min_pressure = min_pressure - atmospheric_pressure_dbar;
        end

        write_nc_variable( ...
            ncfile, ...
            'min_pressure', ...
            min_pressure, ...
            {'burst', nBursts}, ...
            'units', 'dbar', ...
            'long_name', 'minimum manometric pressure', ...
            'pressure_reference', 'manometric');
    end

    if ismember("max_pressure", nc_var_names_string)

        max_pressure = double(ncread(ncfile, 'max_pressure'));

        if pressure_atmospheric_correction_applied
            max_pressure = max_pressure - atmospheric_pressure_dbar;
        end

        write_nc_variable( ...
            ncfile, ...
            'max_pressure', ...
            max_pressure, ...
            {'burst', nBursts}, ...
            'units', 'dbar', ...
            'long_name', 'maximum manometric pressure', ...
            'pressure_reference', 'manometric');
    end
end


%% Crear vectores de tiempo
sample_offset_s = (0:nSamples-1)' / sampling_rate;
burst_time = sample_offset_s + reshape(time, 1, []);

if ast_available
    ast_sampling_rate_Hz = 2*sampling_rate;
    sample_ast_offset_s = (0:2*nSamples-1)'/ast_sampling_rate_Hz;
    burst_time_ast = sample_ast_offset_s + reshape(time,1,[]);
else
    burst_time_ast = nan(2*nSamples, nBursts);
end

%% Procesamiento de las señales AST en caso de estar disponible

if ast_available
    %Señales individuales originales
    AST1 = squeeze(ast(:, 1, :));
    AST2 = squeeze(ast(:, 2, :));
    
    %Asegurar vector columna si solo hay un estado de mar
    if isrow(AST1)
        AST1 = AST1(:);
    end
    if isrow(AST2)
        AST2 = AST2(:);
    end
    
    ast_corr = nan(size(ast));
    ast_bad_detects = nan(2, nBursts);
    ast_bad_detects_percentage = nan(2, nBursts);
    
    if ast_corr_flag
        for b = 1:nBursts
            out_corr = wsa_ast_corr(AST1(:, b), AST2(:, b), sampling_rate);
        
            ast_corr(:, 1, b) = out_corr.ast_corr(:, 1);
            ast_corr(:, 2, b) = out_corr.ast_corr(:, 2);
        
            ast_bad_detects(1, b) = out_corr.bad_detects(:, 1);
            ast_bad_detects(2, b) = out_corr.bad_detects(:, 2);
        
            ast_bad_detects_percentage(1, b) = out_corr.bad_detects_percentage(:, 1);
            ast_bad_detects_percentage(2, b) = out_corr.bad_detects_percentage(:, 2);
        end
    else
        ast_corr = ast;
    end
    
    %Combinar señales AST
    ast_corr_comb = nan(2*nSamples,nBursts);
    for b = 1:nBursts
        ast_corr_comb_out = wsa_ast_combine(ast_corr(:, 1, b), ast_corr(:, 2, b), sampling_rate);
        ast_corr_comb(:, b) = ast_corr_comb_out.ast;
    end
    ast_mean = mean(ast_corr_comb, 1, 'omitnan');   % [1 x nBursts]

    % Detrend
    for b = 1:nBursts
        for iAST = 1:2
            x = ast_corr(:,iAST,b);
            ast_corr(:,iAST,b) = detrend(x,1);
        end
    end
    for b = 1:nBursts
        x_comb = ast_corr_comb(:,b);
        ast_corr_comb(:,b) = detrend(x_comb,1);
    end
else

    ast_corr = nan(nSamples, 2, nBursts);
    ast_corr_comb = nan(2*nSamples, nBursts);
    ast_mean = nan(nBursts, 1);
    ast_bad_detects = nan(2, nBursts);
    ast_bad_detects_percentage = nan(2, nBursts);

    if ast_corr_flag
        fprintf('\nCorrección AST omitida: el instrumento %s no dispone de mediciones AST.\n', instrument_type);
    end
end

%% Transformación de las velocidades beam a enu

velocity_enu = nan(nSamples, 3, nBursts);

if ~velocity_available
    fprintf('\nTransformación de velocidades omitida: el instrumento %s no dispone de mediciones de velocidades orbitales.\n', instrument_type);

else
    switch coordinate_system
        case "BEAM"
            if ~transformation_available || ~heading_available || ~pitch_available || ~roll_available
                error('No es posible transformar velocidades desde BEAM porque faltan la matriz de transformación o los datos de orientación.');
            end

            for b = 1:nBursts
                beam = [velocity_beams(:, 1, b) velocity_beams(:, 2, b) velocity_beams(:, 3, b)]';
                vel_out = wsa_velocity_transformation(beam, transformation_matrix, heading(b), pitch(b), roll(b));
                velocity_enu(:, 1, b) = vel_out.enu(1, :);
                velocity_enu(:, 2, b) = vel_out.enu(2, :);
                velocity_enu(:, 3, b) = vel_out.enu(3, :);
            end
        
        case "ENU"
            if is_awac
                if ~transformation_available || ~heading_available || ~pitch_available || ~roll_available
                    error('No es posible transformar velocidades desde BEAM porque faltan la matriz de transformación o los datos de orientación.');
                end
                for b = 1:nBursts
                    beam = [velocity_beams(:, 1, b) velocity_beams(:, 2, b) velocity_beams(:, 3, b)]';
                    vel_out = wsa_velocity_transformation(beam, transformation_matrix, heading(b), pitch(b), roll(b));
                    velocity_enu(:, 1, b) = vel_out.enu(1, :);
                    velocity_enu(:, 2, b) = vel_out.enu(2, :);
                    velocity_enu(:, 3, b) = vel_out.enu(3, :);
                end
            else
                velocity_enu = velocity_beams;
                fprintf('\nTransformación de coordenadas de velocidades omitida: el instrumento se configuró en ENU.\n');
            end
        case  "XYZ"
            error('Transformación desde XYZ no soportado en esta versión.')

        otherwise
            error('Sistema de coordenadas indicado no corresponde a una opción valida.')
    end
end

%% Calcular presión media
pressure_mean = mean(pressure, 1, 'omitnan').';

%% Calcular variables adicionales: profunidad y posición de sensores del instrumento

% Inicializar variables
z_p = nan(nBursts,1);       %pressure_sensor_z
h = nan(nBursts,1);         %water_depth
z_v = nan(nBursts,1);       %velocity_sensor_z

switch instrument_type

    case "AWAC"
        z_p = -ast_mean(:);                %pressure_sensor_z
        h = ast_mean(:) + mounting_height; %water_depth
        z_v = cell_position(:) - ast_mean(:); %velocity_sensor_z

    case "AQUADOPP"
        g = 9.81;   %m's^2
        rho = 1025; %kg/m^3
        pressure_mean_Pa = 10000*pressure_mean;     % dBa -> Pa    %1dBa = 10kPa (Primero se pasa a unidades SI)
        pressure_mean_m = pressure_mean_Pa./(rho*g);  % Pa -> m de columna de agua
    
        z_p = -pressure_mean_m;                             %pressure_sensor_z
        h = pressure_mean_m + mounting_height;              %water_depth
        z_v = cell_position(:) - pressure_mean_m;              %velocity_sensor_z
    case "RBR"

        g = 9.81;

        % Ruskin normalmente exporta la densidad.
        if isfinite(rbr_density)
            
            % Asegurar kg/m^3
            if rbr_density < 10
                rho = 1000*rbr_density;
            else
                rho = rbr_density;
            end

        else
            rho = 1025;
            warning('No se encontró la densidad configurada en Ruskin. Se utilizará 1025 kg/m^3.');
        end

        if pressure_reference ~= "manometric"
            error('La presión RBR no fue estandarizada correctamente a presión manométrica.');
        end
        
        pressure_mean_Pa = 10000*pressure_mean;
        pressure_mean_m = pressure_mean_Pa/(rho*g);
        z_p = -pressure_mean_m;

        if isfinite(mounting_height)
            h = pressure_mean_m + mounting_height;
        end

        % El RBR no mide velocidades orbitales.
        z_v(:) = NaN;

    otherwise
        error('Instrumento no válido')
end


%% Detrend de presión y velocidades


% Presión
for b = 1:nBursts
    x = pressure(:,b);
    pressure(:,b) = detrend(x,1);
end

% Velocidades ENU
if velocity_available
    for b = 1:nBursts
        for component = 1:3
            x = velocity_enu(:,component,b);
            velocity_enu(:,component,b) = detrend(x,1);
        end
    end
end

%% Inicializar variables procesadas

pressure_proc = nan(nSamples, nBursts);
velocity_proc = nan(nSamples, 3, nBursts);
ast_proc = nan(nSamples, 2, nBursts);
ast_proc_comb = nan(2*nSamples, nBursts);
pressure_proc_IG = nan(nSamples, nBursts);
velocity_proc_IG = nan(nSamples, 3, nBursts);
ast_proc_IG = nan( nSamples, 2, nBursts);
ast_proc_comb_IG = nan(2*nSamples, nBursts);


%% Filtrado de las señales de presión, ast y velocidades en banda de freuencia apta para el análisis direccional

% Se aplica un filtro pasabanda con las siguientes frecuencias de corte:
%  - Frecuecia de corte inferior: 1/30 Hz (30 s)
%  - Frecuencia de corte superior: 1/2 Hz (2 s)

f_i = 1/30;
f_f = 1/2; 

if filter_flag

    % Presión
    pressure_proc = wsa_bandpass_filter(pressure, sampling_rate, f_i, f_f);

    % Velocidades ENU
    if velocity_available
        velocity_proc = nan(size(velocity_enu));
        for iVel = 1:3
            vel_i = squeeze(velocity_enu(:, iVel, :));
    
            if isrow(vel_i)
                vel_i = vel_i(:);
            end
    
            vel_filt = wsa_bandpass_filter(vel_i, sampling_rate, f_i, f_f);
            velocity_proc(:, iVel, :) = reshape(vel_filt, size(velocity_enu,1), 1, []);
    
        end
    end

    % AWAC: AST
    if ast_available
        ast_proc = nan(size(ast_corr));
        for iAST = 1:2
            AST_i = squeeze(ast_corr(:, iAST, :));
    
            if isrow(AST_i)
                AST_i = AST_i(:);
            end
    
            ast_filt = wsa_bandpass_filter(AST_i, sampling_rate, f_i, f_f);
    
            ast_proc(:, iAST, :) = reshape(ast_filt, size(ast_corr,1), 1, []);
        end
        ast_proc_comb = wsa_bandpass_filter(ast_corr_comb, 2*sampling_rate, f_i, f_f);
    end

else
    pressure_proc = pressure;
    if velocity_available
        velocity_proc = velocity_enu;
    end

    if ast_available
        ast_proc = ast_corr;
        ast_proc_comb = ast_corr_comb;
    end
end

%% Filtrado de las señales de presión, ast y velocidades en la banda de frecuencia IG

% Se aplica un filtro pasabanda con las siguientes frecuencias de corte:
%  - Frecuecia de corte inferior: 1/300 Hz (300 s)
%  - Frecuencia de corte superior: 1/30 Hz (30 s)

f_i_IG = 1/300;
f_f_IG = 1/30; 

if IG_filter_flag

    % Presión
    pressure_proc_IG = wsa_bandpass_filter(pressure, sampling_rate, f_i_IG, f_f_IG);

    % Velocidades ENU
    if velocity_available
        velocity_proc_IG = nan(size(velocity_enu));
        for iVel = 1:3
            vel_i = squeeze(velocity_enu(:, iVel, :));
    
            if isrow(vel_i)
                vel_i = vel_i(:);
            end
    
            vel_filt = wsa_bandpass_filter(vel_i, sampling_rate, f_i_IG, f_f_IG);
    
            velocity_proc_IG(:, iVel, :) = reshape(vel_filt, size(velocity_enu,1), 1, []);
        end
    end

    % AWAC: AST
    if ast_available
        ast_proc_IG = nan(size(ast_corr));
        for iAST = 1:2
            AST_i = squeeze(ast_corr(:, iAST, :));
    
            if isrow(AST_i)
                AST_i = AST_i(:);
            end
    
            ast_filt_IG = wsa_bandpass_filter(AST_i, sampling_rate, f_i_IG, f_f_IG);
    
            ast_proc_IG(:, iAST, :) = reshape(ast_filt_IG, size(ast_corr,1), 1, []);
        end
        ast_proc_comb_IG = wsa_bandpass_filter(ast_corr_comb, 2*sampling_rate, f_i_IG, f_f_IG);
    end
end


%% Escribir nuevas variables al archivo netCDF

write_nc_variable(ncfile, 'burst_time', burst_time, ...
    {'sample', size(burst_time,1), ...
     'burst', size(burst_time,2)}, ...
     'units', 'seconds since 1970-01-01 00:00:00 UTC');

write_nc_variable(ncfile, 'h', h, ...
    {'burst', nBursts}, ...
     'units', 'm', ...
     'description', 'Profundidad del lecho marino');

write_nc_variable(ncfile, 'z_p', z_p, ...
    {'burst', nBursts}, ...
     'units', 'm', ...
     'description', 'Ubicación del sensor de presión desde el nivel medio');

write_nc_variable(ncfile, 'z_v', z_v, ...
    {'burst', nBursts}, ...
     'units', 'm', ...
     'description', 'Ubicación de las mediciones de velocidades orbitales desde el nivel medio');

write_nc_variable(ncfile, 'pressure_proc', pressure_proc, ...
    {'sample', size(pressure_proc,1), ...
     'burst', size(pressure_proc,2)}, ...
     'units', 'dBar', ...
     'pressure_reference', 'manometric', ...
     'description', 'Presión procesada mediante filtro pasa banda de en las frecuencias de 1/30 Hz a 1/2 Hz');

write_nc_variable(ncfile, 'velocity_enu', velocity_enu, ...
    {'sample', size(velocity_enu,1), ...
     'enu_component', size(velocity_enu,2), ...
     'burst', size(velocity_enu,3)}, ...
     'units', 'm/s', ...
     'description', 'Velocidades orbitales en sistema de coordenadas ENU. enu_components: 1-East, 2-North, 3-Up.');

write_nc_variable(ncfile, 'velocity_proc', velocity_proc, ...
    {'sample', size(velocity_proc,1), ...
     'enu_component', size(velocity_proc,2), ...
     'burst', size(velocity_proc,3)}, ...
     'units', 'm/s', ...
     'description', 'Velocidades orbitales en sistema de coordenadas ENU. enu_components: 1-East, 2-North, 3-Up. Procesada mediante filtro pasa banda de en las frecuencias de 1/30 Hz a 1/2 Hz');


write_nc_variable(ncfile, 'pressure_proc_IG', pressure_proc_IG, ...
    {'sample', size(pressure_proc_IG,1), ...
     'burst', size(pressure_proc_IG,2)}, ...
     'units', 'dBar', ...
     'pressure_reference', 'manometric', ...
     'description', 'Presión procesada mediante filtro pasa banda de en las frecuencias de 1/300 Hz a 1/30 Hz');

write_nc_variable(ncfile, 'velocity_proc_IG', velocity_proc_IG, ...
    {'sample', size(velocity_proc_IG,1), ...
     'enu_component', size(velocity_proc_IG,2), ...
     'burst', size(velocity_proc_IG,3)}, ...
     'units', 'm/s', ...
     'description', 'Velocidades orbitales en sistema de coordenadas ENU. enu_components: 1-East, 2-North, 3-Up. Procesada mediante filtro pasa banda de en las frecuencias de 1/300 Hz a 1/30 Hz');

write_nc_variable(ncfile, 'pressure_mean', pressure_mean, ...
    {'burst', nBursts}, ...
    'units', 'dbar', ...
     'pressure_reference', 'manometric', ...
    'description', 'Presión media.');


write_nc_variable(ncfile, 'burst_time_ast', burst_time_ast, ...
    {'sample_ast', size(burst_time_ast,1), ...
     'burst', size(burst_time_ast,2)}, ...
     'units', 'seconds since 1970-01-01 00:00:00 UTC', ...
     'description', 'Tiempo para señal AST combinada (doble frecuencia de muestreo).');

write_nc_variable(ncfile, 'ast_proc', ast_proc, ...
    {'sample', size(ast_proc,1), ...
     'ast_sensor', size(ast_proc,2), ...
     'burst', size(ast_proc,3)}, ...
     'units', 'm', ...
     'description', 'AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa banda de en las frecuencias de 1/30 Hz a 1/2 Hz');

write_nc_variable(ncfile, 'ast_proc_comb', ast_proc_comb, ...
    {'sample_ast', size(ast_proc_comb,1), ...
     'burst', size(ast_proc_comb,2)}, ...
     'units', 'm', ...
     'description', 'AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa banda de en las frecuencias de 1/30 Hz a 1/2 Hz. Señal combinada a doble frecuencia de muestreo.');

write_nc_variable(ncfile, 'ast_mean', ast_mean, ...
    {'burst', nBursts}, ...
     'units', 'm', ...
     'description', 'AST promedio');

write_nc_variable(ncfile, 'ast_bad_detects', ast_bad_detects, ...
    {'ast_sensor', size(ast_bad_detects,1), ...
     'burst', size(ast_bad_detects,2)}, ...
     'units', 'count', ...
     'description', 'Mediciones malas del AST.');

write_nc_variable(ncfile, 'ast_bad_detects_percentage', ast_bad_detects_percentage, ...
    {'ast_sensor', size(ast_bad_detects_percentage,1), ...
     'burst', size(ast_bad_detects_percentage,2)}, ...
     'units', 'percentage', ...
     'description', 'Porcentaje de mediciones malas del AST.');


write_nc_variable(ncfile, 'ast_proc_IG', ast_proc_IG, ...
    {'sample', size(ast_proc_IG,1), ...
     'ast_sensor', size(ast_proc_IG,2), ...
     'burst', size(ast_proc_IG,3)}, ...
     'units', 'm', ...
     'description', 'AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa banda de en las frecuencias de 1/300 Hz a 1/30 Hz');

write_nc_variable(ncfile, 'ast_proc_comb_IG', ast_proc_comb_IG, ...
    {'sample_ast', size(ast_proc_comb_IG,1), ...
     'burst', size(ast_proc_comb_IG,2)}, ...
     'units', 'm', ...
     'description', 'AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa banda de en las frecuencias de 1/300 Hz a 1/30 Hz. Señal combinada a doble frecuencia de muestreo.');




%% Atributos del procesamiento

ncwriteatt(ncfile, '/', 'preprocessing_instrument_type', char(instrument_type));

ncwriteatt(ncfile, '/', 'preprocessing_pressure_available', double(pressure_available));
ncwriteatt(ncfile, '/', 'preprocessing_velocity_available', double(velocity_available));
ncwriteatt(ncfile, '/', 'preprocessing_AST_available', double(ast_available));

ncwriteatt(ncfile, '/', 'pressure_reference_original', char(pressure_reference_original));
ncwriteatt(ncfile, '/', 'pressure_reference', 'manometric');
ncwriteatt(ncfile, '/', 'pressure_atmospheric_correction_applied', double(pressure_atmospheric_correction_applied));
ncwriteatt(ncfile, '/', 'pressure_atmospheric_correction_dbar', double(pressure_atmospheric_correction_dbar));
ncwriteatt(ncfile, '/', 'pressure_standardized_during_preprocessing', double(true));

ncwriteatt(ncfile, '/', 'preprocessing_filter_flag', double(filter_flag));
ncwriteatt(ncfile, '/', 'preprocessing_IG_filter_flag', double(IG_filter_flag));
ncwriteatt(ncfile, '/', 'preprocessing_AST_correction_flag', double(ast_available && ast_corr_flag));
ncwriteatt(ncfile, '/', 'preprocessing_bandpass_fi_Hz', f_i);
ncwriteatt(ncfile, '/', 'preprocessing_bandpass_ff_Hz', f_f);

if IG_filter_flag
    ncwriteatt(ncfile, '/', 'preprocessing_bandpass_IG_fi_Hz', f_i_IG);
    ncwriteatt(ncfile, '/', 'preprocessing_bandpass_IG_ff_Hz', f_f_IG);
end

%Indicar que se aplicó el preprocesamiento
ncwriteatt(ncfile, '/', 'preprocessing_status', double(true));

%% Guardar información

info = struct();

info.pressure.raw = pressure; % Sin detrend ni filtro, pero manométrica
info.pressure.unfiltered = pressure;
info.pressure.reference = "manometric";
info.pressure.original_reference = pressure_reference_original;
info.pressure.atmospheric_correction_applied = pressure_atmospheric_correction_applied;
info.pressure.atmospheric_correction_dbar = pressure_atmospheric_correction_dbar;
info.pressure.proc = pressure_proc;
info.pressure.proc_IG = pressure_proc_IG;

info.velocity_beams.raw = velocity_beams;
info.velocity_enu.raw = velocity_enu;
info.velocity_enu.proc = velocity_proc;
info.velocity_enu.proc_IG = velocity_proc_IG;

info.instrument_type = instrument_type;

info.pressure.available = pressure_available;

info.velocity_beams.available = velocity_available;
info.velocity_enu.available = velocity_available;

info.ast.available = ast_available;
info.ast.raw = ast;
info.ast.corr = ast_corr;
info.ast.proc = ast_proc;
info.ast.proc_comb = ast_proc_comb;
info.ast.proc_IG = ast_proc_IG;
info.ast.proc_comb_IG = ast_proc_comb_IG;
info.ast.mean = ast_mean;
info.ast.ast_bad_detects = ast_bad_detects;
info.ast.ast_bad_detects_percentage = ast_bad_detects_percentage;

info.transformation_matrix = transformation_matrix;
info.heading = heading;
info.pitch = pitch;
info.roll = roll;

info.filter.flag = filter_flag;
info.filter.f_i = f_i;
info.filter.f_f = f_f;

info.filter.IG_flag = IG_filter_flag;
if IG_filter_flag
    info.filter.f_i_IG = f_i_IG;
    info.filter.f_f_IG = f_f_IG;
end

%% Graficos de prueba

% burst = 5;
% 
% figure;
% 
% subplot(4, 1, 1)
% hold on; title('Pressure');
% plot(pressure(:, burst)); plot(pressure_proc(:, burst))
% legend('presión original', 'presión filtrada')
% 
% subplot(4, 1, 2)
% hold on; title('AST');
% plot(ast_corr(:, 1, burst)); plot(ast_proc(:, 1, burst))
% legend('AST original', 'AST filtrada')
% 
% subplot(4, 1, 3)
% hold on; title('Velocidad U');
% plot(velocity_enu(:, 1, burst)); plot(velocity_proc(:, 1, burst))
% legend('U original', 'U filtrada')
% 
% subplot(4, 1, 4)
% hold on; title('Velocidad V');
% plot(velocity_enu(:, 2, burst)); plot(velocity_proc(:, 2, burst))
% legend('V original', 'V filtrada')

fprintf('\n========================================================================================================================\n');
end

%% Funciones auxiliares específicas de la función

function write_nc_variable(ncfile, varname, data, dimensions, varargin)

FILL_DOUBLE = double(9.969209968386869e36);
DEFLATE_LEVEL = 4;
SHUFFLE_FLAG = true;

file_info = ncinfo(ncfile);
existing_vars = {file_info.Variables.Name};

is_new_variable = ~ismember(varname,existing_vars);

if is_new_variable

    chunk_size = infer_chunk_size(dimensions);

    wsa_nc_create_var( ...
        ncfile, ...
        varname, ...
        dimensions, ...
        'double', ...
        'FillValue', FILL_DOUBLE, ...
        'DeflateLevel', DEFLATE_LEVEL, ...
        'Shuffle', SHUFFLE_FLAG, ...
        'ChunkSize', chunk_size, ...
        varargin{:});

else

    % Actualizar atributos normales.
    for k = 1:2:numel(varargin)
        ncwriteatt( ...
            ncfile, ...
            varname, ...
            varargin{k}, ...
            varargin{k+1});
    end
end

data = double(data);

data_available = any(isfinite(data(:)));

ncwriteatt( ...
    ncfile, ...
    varname, ...
    'data_available', ...
    double(data_available));

if ~data_available && is_new_variable
    % La variable queda sin escribir y netCDF devuelve _FillValue.
    return
end

% Este caso también limpia una variable existente cuando se vuelve
% a ejecutar preprocess con una opción desactivada.
data(~isfinite(data)) = FILL_DOUBLE;

ncwrite(ncfile,varname,data);

end



function chunk_size = infer_chunk_size(dimensions)

dim_lengths = cell2mat(dimensions(2:2:end));

chunk_size = dim_lengths;

% Primera dimensión normalmente corresponde a sample.
if ~isempty(chunk_size)
    chunk_size(1) = min(chunk_size(1),1024);
end

% Última dimensión normalmente corresponde a burst.
if numel(chunk_size) >= 2
    chunk_size(end) = 1;
end

end

function value = read_att_safe(ncfile, location, attribute_name, default_value)
try
    value = ncreadatt(ncfile, location, attribute_name);
catch
    value = default_value;
end
end

function tf = nc_variable_available(ncfile, varname, nc_var_names)
%nc_variable_available - determina si una variable netCDF contiene datos.

tf = false;

if ~ismember(string(varname), nc_var_names)
    return
end

att = ncreadatt(ncfile,varname, 'data_available');
tf = logical(att);

end



