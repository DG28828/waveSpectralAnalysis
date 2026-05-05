function info = wsa_awac_process(ncfile, varargin)

%%
%ncfile = 'C:\COPC_db\processed\Moin_Isla\2026-02_2026-03\Moin_Isla_2026-02_2026-03_clean.nc';

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
fprintf('====================================          Preprocesamiento de datos de AWAC         ====================================\n');
fprintf('\nPreprocesar datos de AWAC.\n');

%Verificar existencia de archivo netCDF
if ~isfile(ncfile)
    error('El archivo no existe: %s', ncfile)
end

% Verificar que las variables a utilizar existan
% ast
% pressure
% velocity_beams
% transformation_matrix
req_var_names = {'ast', 'pressure', 'velocity_beams', 'transformation_matrix', 'heading', 'pitch', 'roll'};
nc_info = ncinfo(ncfile);
nc_var_names = {nc_info.Variables.Name};

if any(~ismember(req_var_names, nc_var_names))
    missing_vars = req_var_names(~ismember(req_var_names, nc_var_names));
    error(['Una o más de las variables requeridas no existe en el archivo %s\n' ...
            'Variables requeridas: %s\n' ...
            'Variables faltantes: %s'], ...
            ncfile, ...
            strjoin(req_var_names, ', '), ...
            strjoin(missing_vars, ', '));
end

%% Extraer datos requeridas
ast = ncread(ncfile, req_var_names{1});
pressure = ncread(ncfile, req_var_names{2});
velocity_beams = ncread(ncfile, req_var_names{3});
transformation_matrix = ncread(ncfile, req_var_names{4});
heading = ncread(ncfile, req_var_names{5});
pitch = ncread(ncfile, req_var_names{6});
roll = ncread(ncfile, req_var_names{7});

[~, ~, nBursts] = size(velocity_beams);

%Extraer wave_sampling_rate
wave_sampling_rate = ncreadatt(ncfile, '/', 'wave_sampling_rate_Hz');
ast_sampling_rate = 2*wave_sampling_rate;

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
ast1_bad_detects = nan(1, nBursts);
ast2_bad_detects = nan(1, nBursts);
ast1_bad_detects_percentage = nan(1, nBursts);
ast2_bad_detects_percentage = nan(1, nBursts);

if ast_corr_flag
    for b = 1:nBursts
        out_ast1_corr = wsa_ast_corr(AST1(:, b), wave_sampling_rate);
        out_ast2_corr = wsa_ast_corr(AST2(:, b), wave_sampling_rate);
    
        ast_corr(:, 1, b) = out_ast1_corr.ast_corr;
        ast_corr(:, 2, b) = out_ast2_corr.ast_corr;
    
        ast1_bad_detects(b) = out_ast1_corr.bad_detects;
        ast2_bad_detects(b) = out_ast2_corr.bad_detects;
    
        ast1_bad_detects_percentage(b) = out_ast1_corr.bad_detects_percentage;
        ast2_bad_detects_percentage(b) = out_ast2_corr.bad_detects_percentage;
    end
else
    ast_corr = ast;
end

%Combinar señales AST
ast_corr_comb = nan(2*size(ast_corr, 1), nBursts); % [nASTSamples x nBursts]
for b = 1:nBursts
    ast_corr_comb_out = wsa_ast_combine(ast_corr(:, 1, b), ast_corr(:, 2, b), wave_sampling_rate);
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
    out_pressure_filt = wsa_highpass_filter(pressure, wave_sampling_rate, fc, filter_order);
    pressure_proc = out_pressure_filt.x_filt;

    % AST
    ast_proc = nan(size(ast_corr));
    for iAST = 1:2
        AST_i = squeeze(ast_corr(:, iAST, :));

        if isrow(AST_i)
            AST_i = AST_i(:);
        end

        out_ast_filt = wsa_highpass_filter(AST_i, wave_sampling_rate, fc, filter_order);

        ast_proc(:, iAST, :) = reshape(out_ast_filt.x_filt, size(ast_corr,1), 1, []);
    end

    % Velocidades ENU
    velocity_proc = nan(size(velocity_enu));
    for iVel = 1:3
        vel_i = squeeze(velocity_enu(:, iVel, :));

        if isrow(vel_i)
            vel_i = vel_i(:);
        end

        out_vel_filt = wsa_highpass_filter(vel_i, wave_sampling_rate, fc, filter_order);

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

write_nc_variable(ncfile, 'pressure_proc', pressure_proc, ...
    {'sample', size(pressure_proc,1), ...
     'burst', size(pressure_proc,2)}, ...
     'units', 'dBar');

write_nc_variable(ncfile, 'ast_proc', ast_proc, ...
    {'sample', size(ast_proc,1), ...
     'ast_sensor', size(ast_proc,2), ...
     'burst', size(ast_proc,3)}, ...
     'units', 'm');

write_nc_variable(ncfile, 'velocity_proc', velocity_proc, ...
    {'sample', size(velocity_proc,1), ...
     'enu_component', size(velocity_proc,2), ...
     'burst', size(velocity_proc,3)}, ...
     'units', 'm/s');

write_nc_variable(ncfile, 'ast_mean', ast_mean, ...
    {'burst', nBursts}, ...
     'units', 'm');

% Atributos de variables procesadas
ncwriteatt(ncfile, 'pressure_proc', 'description', ...
    'Presion procesada. Filtrado opcional');

ncwriteatt(ncfile, 'ast_proc', 'description', ...
    'AST procesado. Despiking, interpolacion y filtrado opcional.');

ncwriteatt(ncfile, 'velocity_proc', 'description', ...
    'Velocidades orbitales en sistema de coordenadas ENU y filtrado opcional. 1: East, 2: North, 3:Up');

ncwriteatt(ncfile, 'ast_mean', 'description', ...
    'Distancia AST promedio');

ncwriteatt(ncfile, '/', 'processing_filter_flag', double(filter_flag));
ncwriteatt(ncfile, '/', 'processing_highpass_fc_Hz', fc);
ncwriteatt(ncfile, '/', 'processing_highpass_order', filter_order);

%Indicar que se aplicó el preprocesamiento
ncwriteatt(ncfile, '/', 'preprocessing_applied', double(true));

%% Guardar información

info.ast.raw = ast;
info.ast.corr = ast_corr;
info.ast.proc = ast_proc;

info.ast.AST1_bad_detects = ast1_bad_detects;
info.ast.AST2_bad_detects = ast2_bad_detects;

info.ast.AST1_bad_detects_percentage = ast1_bad_detects_percentage;
info.ast.AST2_bad_detects_percentage = ast2_bad_detects_percentage;

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