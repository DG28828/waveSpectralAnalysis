function data_clean = wsa_awac_clean(data_in, varargin)
%wsa_awac_clean - limpia datos AWAC a partir de flags de calidad.
%
%   Esta función elimina bursts problemáticos de una estructura de datos
%   AWAC previamente importada mediante wsa_awac_read, o reconstruida desde
%   un archivo raw.nc.
%
%   La limpieza puede realizarse de forma automática, utilizando los flags
%   de calidad generados durante la lectura de los datos, o de forma manual,
%   indicando directamente los índices de los bursts que se desean eliminar.
%
%
%   Sintaxis:
%       data_clean = wsa_awac_clean(data_in)
%
%       data_clean = wsa_awac_clean(data_in, 'man', true, 'clean_idx', clean_idx)
%
%
%   Argumentos de entrada (requeridos):
%       data_in   - Datos AWAC crudos.
%                   Puede ser:
%
%                       1) Estructura data generada por wsa_awac_read.
%
%                       2) Ruta a un archivo raw.nc generado previamente.
%                          String | char.
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'man'     - Bandera para activar limpieza manual.
%                   true | false
%                   Por defecto: false.
%
%       'clean_idx'
%                 - Índices de bursts que se desean eliminar manualmente.
%                   Vector de enteros positivos.
%
%                   Este parámetro es requerido cuando: 'man' = true                  
%
%
%   Argumentos de salida:
%       data_clean - Estructura AWAC limpia.
%
%                    Conserva la estructura general de data_in, pero elimina
%                    de los campos whd y wad los bursts marcados como malos.
%
%                    Además, agrega o actualiza:
%
%                    cleaning.Number_of_wave_measurements
%                    cleaning.time_start
%                    cleaning.time_end
%                    cleaning.cleaning_type
%                    cleaning_status
%
%
%   Notas:
%   • En modo automático, la función elimina los bursts indicados en:
%
%         data.quality.summary.bad_bursts
%
%   • En modo manual, la función elimina únicamente los bursts indicados
%     mediante clean_idx.
%
%   • La función no modifica las series temporales dentro de cada burst.
%     Únicamente elimina bursts completos.
%
%   • La función verifica que los datos de entrada no hayan sido limpiados
%     previamente mediante el campo cleaning_status.
%
%   • Si data_in corresponde a una ruta raw.nc, la estructura data se
%     reconstruye internamente mediante wsa_awac_nc_read_raw.
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 10/03/2026
% Fecha de modificación: 19/05/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
man_def = false;        %Flag para limpieza manual - falso por defecto
clean_idx_def = [];     %Indices de estados de mar a limpiar - ninguno por defecto

p = inputParser;

addRequired(p, 'data_in');

addParameter(p, 'man', man_def);
addParameter(p, 'clean_idx', clean_idx_def);

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
    data = wsa_awac_nc_read_raw(ncfile);

elseif isstruct(data_in)
    data = data_in;

else
    error('La entrada debe ser un struct data o la ruta a un archivo raw.nc.');
end


%% Verificaciones iniciales

fprintf('\n\n========================================================================================================================\n');
fprintf('===========================================          Limpieza de AWAC         ===========================================\n');
fprintf('\nLimpiar datos de archivos crudos de AWAC.\n');

%Verificar si ya se hizo una limpieza
if data.cleaning_status
    error('Ya se ha realizado una limpieza previa de los datos ingresados, ingrese datos crudos.')
end

if man
    if isempty(clean_idx)
        error('El modo manual de limpieza requiere que se indique los índices (bursts) a limpiar, mediante el vector clean_idx');
    end
end

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
data_clean.cleaning_status = true;

%Indicar tipo de limpieza realizada
if ~man
    data_clean.cleaning.cleaning_type = 'automatic';
else
    data_clean.cleaning.cleaning_type = 'manual';
end



fprintf('\n========================================================================================================================\n');
end