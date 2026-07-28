function info = wsa_nc_preprocess(ncfile, varargin)
%wsa_nc_preprocess - preprocesa señales de oleaje guardadas en netCDF para instrumentos de medición.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 10/03/2026
% Fecha de modificación: 28/07/2026
% -------------------------------------------------------------------------
%% Manejo de entradas

ast_corr_flag_default = true;
filter_flag_default = true;

p = inputParser;
addRequired(p, 'ncfile');
addParameter(p, 'ast_corr_flag', ast_corr_flag_default)
addParameter(p, 'filter_flag', filter_flag_default);

parse(p, ncfile, varargin{:});

ast_corr_flag = p.Results.ast_corr_flag;
filter_flag = p.Results.filter_flag;

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

if ~ismember(instrument_type, ["AWAC", "AQUADOPP"])
    error(['El atributo global instrument_type no existe o no contiene ' ...
           'un instrumento compatible. Valor encontrado: "%s".'], ...
           instrument_type);
end
is_awac = instrument_type == "AWAC";
is_aquadopp = instrument_type == "AQUADOPP";

fprintf('\nInstrumento: %s.\n', instrument_type);


%% Verificar variables requeridas

common_req_vars = {'time', 'pressure', 'velocity_beams', 'transformation_matrix', 'heading', 'pitch', 'roll'};
awac_req_vars = {'ast'};

nc_info = ncinfo(ncfile);
nc_var_names = string({nc_info.Variables.Name});

required_vars = string(common_req_vars);

if is_awac
    required_vars = [required_vars, string(awac_req_vars)];
end

missing_vars = required_vars(~ismember(required_vars, nc_var_names));

if ~isempty(missing_vars)
    error('El archivo no contiene todas las variables requeridas.\nInstrumento: %s\nVariables faltantes: %s', instrument_type, strjoin(missing_vars, ', '));
end

%% Extraer datos requeridas

time = ncread(ncfile, 'time');

pressure = ncread(ncfile, 'pressure');
velocity_beams = ncread(ncfile, 'velocity_beams');
transformation_matrix = ncread(ncfile, 'transformation_matrix');
heading = ncread(ncfile, 'heading');
pitch = ncread(ncfile, 'pitch');
roll = ncread(ncfile, 'roll');

nSamples = size(pressure, 1);
nBursts  = size(pressure, 2);

if size(velocity_beams, 1) ~= nSamples || size(velocity_beams, 3) ~= nBursts
    error('Las dimensiones de pressure y velocity_beams no son consistentes.');
end

if is_awac
    ast = double(ncread(ncfile, 'ast'));
    if size(ast, 1) ~= nSamples || size(ast, 3) ~= nBursts
        error('Las dimensiones de ast no coinciden con pressure.');
    end
else
    % Mantener estructura estándar para Aquadopp.
    ast = nan(nSamples, 2, nBursts);
end

%% Información de muestreo

sampling_rate_Hz = double(read_att_safe(ncfile, '/', 'sampling_rate_Hz', NaN));

number_of_samples_att = double(read_att_safe(ncfile, '/', 'number_of_samples', NaN));

if ~isfinite(sampling_rate_Hz) || sampling_rate_Hz <= 0
    % Compatibilidad con archivos AWAC anteriores.
    sampling_rate_Hz = double(read_att_safe(ncfile, '/', 'wave_sampling_rate_Hz', NaN));
end

if ~isfinite(sampling_rate_Hz) || sampling_rate_Hz <= 0
    error('El archivo no contiene una frecuencia de muestreo válida.');
end

if isfinite(number_of_samples_att) && ...
    number_of_samples_att ~= nSamples
    warning('El atributo number_of_samples indica %d muestras, pero la dimensión sample contiene %d. Se utilizará %d.', number_of_samples_att, nSamples, nSamples);
end

%% Crear vectores de tiempo
sample_offset_s = (0:nSamples-1)' / sampling_rate_Hz;
burst_time = sample_offset_s + reshape(time, 1, []);   %% Continuar aqui

%% Procesamiento de las señales AST

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
        out_corr = wsa_ast_corr(AST1(:, b), AST2(:, b), sampling_rate_Hz);
    
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
ast_corr_comb = nan(2*size(ast_corr, 1), nBursts); % [nASTSamples x nBursts]
for b = 1:nBursts
    ast_corr_comb_out = wsa_ast_combine(ast_corr(:, 1, b), ast_corr(:, 2, b), sampling_rate_Hz);
    ast_corr_comb(:, b) = ast_corr_comb_out.ast;
end
ast_mean = mean(ast_corr_comb, 1, 'omitnan');   % [1 x nBursts]

%% Transformación de las velocidades beam a enu

velocity_enu = nan(size(velocity_beams));
for b = 1:nBursts
    % Extraer datos del burst
    U_beam = velocity_beams(:, 1, b);
    V_beam = velocity_beams(:, 2, b);
    Z_beam = velocity_beams(:, 3, b);

    %Preprocesamiento de las velocidades
    beam = [U_beam V_beam Z_beam]';
    vel_out = wsa_velocity_transformation(beam, transformation_matrix, heading(b), pitch(b), roll(b));
    velocity_enu(:, 1, b) = vel_out.enu(1, :);
    velocity_enu(:, 2, b) = vel_out.enu(2, :);
    velocity_enu(:, 3, b) = vel_out.enu(3, :);
end

%% Filtrado de las señales de presión, ast y velocidades
fc = 1/340; % Hz        %Frecuencia de corte
filter_order = 4;       %Orden del filtro

if filter_flag

    % Presión
    out_pressure_filt = wsa_highpass_filter(pressure, sampling_rate_Hz, fc, filter_order);
    pressure_proc = out_pressure_filt.x_filt;

    % AST
    ast_proc = nan(size(ast_corr));
    for iAST = 1:2
        AST_i = squeeze(ast_corr(:, iAST, :));

        if isrow(AST_i)
            AST_i = AST_i(:);
        end

        out_ast_filt = wsa_highpass_filter(AST_i, sampling_rate_Hz, fc, filter_order);

        ast_proc(:, iAST, :) = reshape(out_ast_filt.x_filt, size(ast_corr,1), 1, []);
    end
    out_ast_filt_comb = wsa_highpass_filter(ast_corr_comb, 2*sampling_rate_Hz, fc, filter_order);
    ast_proc_comb = out_ast_filt_comb.x_filt;

    % Velocidades ENU
    velocity_proc = nan(size(velocity_enu));
    for iVel = 1:3
        vel_i = squeeze(velocity_enu(:, iVel, :));

        if isrow(vel_i)
            vel_i = vel_i(:);
        end

        out_vel_filt = wsa_highpass_filter(vel_i, sampling_rate_Hz, fc, filter_order);

        velocity_proc(:, iVel, :) = reshape( ...
            out_vel_filt.x_filt, ...
            size(velocity_enu,1), ...
            1, ...
            []);
    end
else
    pressure_proc = pressure;
    ast_proc = ast_corr;
    velocity_proc = velocity_enu;
end

%% Escribir nuevas variables al archivo netCDF

write_nc_variable(ncfile, 'burst_time', burst_time, ...
    {'sample', size(burst_time,1), ...
     'burst', size(burst_time,2)}, ...
     'units', 'seconds since 1970-01-01 00:00:00 UTC');

write_nc_variable(ncfile, 'burst_time_ast', burst_time_ast, ...
    {'sample_ast', size(burst_time_ast,1), ...
     'burst', size(burst_time_ast,2)}, ...
     'units', 'seconds since 1970-01-01 00:00:00 UTC', ...
     'description', 'Tiempo para señal AST combinada (doble frecuencia de muestreo).');

write_nc_variable(ncfile, 'pressure_proc', pressure_proc, ...
    {'sample', size(pressure_proc,1), ...
     'burst', size(pressure_proc,2)}, ...
     'units', 'dBar', ...
     'description', ['Presión procesada mediante filtro pasa altas con fc de ', num2str(fc), ' Hz.']);

write_nc_variable(ncfile, 'ast_proc', ast_proc, ...
    {'sample', size(ast_proc,1), ...
     'ast_sensor', size(ast_proc,2), ...
     'burst', size(ast_proc,3)}, ...
     'units', 'm', ...
     'description', ['AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa altas con fc de ', num2str(fc), ' Hz.']);

write_nc_variable(ncfile, 'ast_proc_comb', ast_proc_comb, ...
    {'sample_ast', size(ast_proc_comb,1), ...
     'burst', size(ast_proc_comb,2)}, ...
     'units', 'm', ...
     'description', ['AST procesado con despiking, corrección por aceleración gravitacional y filtro pasa altas con fc de ', num2str(fc), ' Hz. Señal combinada a doble frecuencia de muestreo.']);

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
     'description', ['Velocidades orbitales en sistema de coordenadas ENU. enu_components: 1-East, 2-North, 3-Up. Procesada mediante filtro pasa altas con fc de ', num2str(fc), ' Hz.']');

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

%Atributos del procesamiento
ncwriteatt(ncfile, '/', 'processing_filter_flag', double(filter_flag));
ncwriteatt(ncfile, '/', 'processing_highpass_fc_Hz', fc);
ncwriteatt(ncfile, '/', 'processing_highpass_order', filter_order);

%Indicar que se aplicó el preprocesamiento
ncwriteatt(ncfile, '/', 'preprocessing_status', double(true));

%% Guardar información

info.ast.raw = ast;
info.ast.corr = ast_corr;
info.ast.proc = ast_proc;

info.ast.ast_bad_detects = ast_bad_detects;
info.ast.ast_bad_detects_percentage = ast_bad_detects_percentage;

info.pressure.raw = pressure;
info.pressure.proc = pressure_proc;

info.velocity_beams.raw = velocity_beams;
info.velocity_enu.raw = velocity_enu;
info.velocity_enu.proc = velocity_proc;

info.transformation_matrix = transformation_matrix;
info.heading = heading;
info.pitch = pitch;
info.roll = roll;

info.filter.flag = filter_flag;
info.filter.fc = fc;
info.filter.order = filter_order;

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
%write_nc_variable - Crea o sobrescribe una variable en un NetCDF.
%
% Uso:
%   write_nc_variable(..., 'units', 'm/s')
%   write_nc_variable(..., 'units', 'm', 'long_name', 'Surface elevation')

info = ncinfo(ncfile);
existing_vars = {info.Variables.Name};

if ~ismember(varname, existing_vars)
    % Crear variable con atributos
    wsa_nc_create_var(ncfile, varname, dimensions, 'double', varargin{:});
else
    % Si ya existe, actualizar atributos si se pasaron
    for k = 1:2:numel(varargin)
        attname = varargin{k};
        attval  = varargin{k+1};
        ncwriteatt(ncfile, varname, attname, attval);
    end
end

% Escribir datos
ncwrite(ncfile, varname, data);
end


function value = read_att_safe(ncfile, location, attribute, default_value)

try
    value = ncreadatt(ncfile, location, attribute);
catch
    value = default_value;
end

end

