function data_clean = wsa_awac_clean(data, varargin)
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
% Fecha de creación: 10/03/2026
% Fecha de modificación: 10/03/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
man_def = false;        %Flag para limpieza manual - falso por defecto
clean_idx_def = [];     %Indices de estados de mar a limpiar - ninguno por defecto

p = inputParser;

addRequired(p, 'data');

addParameter(p, 'man', man_def);
addParameter(p, 'clean_idx', clean_idx_def);

parse(p, data, varargin{:});

man = p.Results.man;
clean_idx = p.Results.clean_idx;


%% Verificaciones iniciales

%Verificar si ya se hizo una limpieza
if data.cleaning_applied
    error('Ya se ha realizado una limpieza previa de los datos ingresados, ingrese datos crudos.')
end

if man
    if isempty(clean_idx)
        error('El modo manual de limpieza requiere que se indique los índices (bursts) a limpiar, mediante el vector clean_idx');
    end
end

fprintf('\n###############################      Limpieza de AWAC      ################################\n');
fprintf('\nLimpiar datos de archivos crudos de AWAC.\n');

%% Limpiar datos (por defecto se limpia según control de calidad de wsa_awac_read)
data_clean = data;

data_clean.cleaning = struct();

if ~man
    fprintf('\nModo de limpieza: automático.\n\n')
    bad_bursts = data.quality.summary.bad_bursts;
else
    fprintf('\nComenzando limpieza de datos.\n\n')
    fprintf('\nModo de limpieza: manual.\n')
    bad_bursts = false(data.quality.summary.total_bursts, 1);
    bad_bursts(clean_idx) = true;

end

good_idx = ~bad_bursts;

% Filtrar estructuras
data_clean.whd = data.whd(good_idx);
data_clean.wad = data.wad(good_idx);

fprintf('Se eliminaron %d bursts. Quedan %d bursts válidos.\n', ...
    sum(bad_bursts), sum(good_idx));

% Reporte de datos actualizados despues de limpieza
data_clean.cleaning.Number_of_wave_measurements = sum(good_idx);
data_clean.cleaning.time_start = data_clean.whd(1).datetime;
data_clean.cleaning.time_end   = data_clean.whd(end).datetime;

% Indicar que se realizó la limpieza
data_clean.cleaning_applied = true;

%Indicar tipo de limpieza realizada
if ~man
    data_clean.cleaning.cleaning_type = 'automatic';
else
    data_clean.cleaning.cleaning_type = 'manual';
end



fprintf('\n##########################################################################################\n');
end