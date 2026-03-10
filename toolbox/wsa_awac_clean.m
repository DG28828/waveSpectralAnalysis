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

%% Limpiar datos (por defecto se limpia según control de calidad de wsa_awac_read)
data_clean = data;

if ~man
    fprintf('\nComenzando limpieza de datos.\n')
    fprintf('\nModo de limpieza: automático.\n')
    bad_bursts = data.quality_control.summary.bad_bursts;
else
    fprintf('\nComenzando limpieza de datos.\n')
    fprintf('\nModo de limpieza: manual.\n')
    bad_bursts = false(data.quality_control.summary.total_bursts, 1);
    bad_bursts(clean_idx) = true;

end

good_idx = ~bad_bursts;

% Filtrar estructuras
data_clean.wave_info = data.wave_info(good_idx);
data_clean.wave_data = data.wave_data(good_idx);

% Actualizar número de bursts
data_clean.general_info.general.Number_of_measurements = sum(good_idx);

fprintf('\tSe eliminaron %d bursts. Quedan %d bursts válidos.\n', ...
    sum(bad_bursts), sum(good_idx));

% Indicar que se realizó la limpieza
data_clean.cleaning_applied = true;

%Indicar tipo de limpieza realizada
if ~man
    data_clean.cleaning_type = 'automatic';
else
    data_clean.cleaning_type = 'manual';
end




end