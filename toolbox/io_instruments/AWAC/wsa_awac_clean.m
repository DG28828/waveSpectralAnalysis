function data_clean = wsa_awac_clean(data_in, varargin)
% wsa_awac_clean - elimina bursts AWAC de forma automática o manual.
%
%    Filtra los campos whd y wad de una campaña importada con wsa_awac_read.
%    Conserva las muestras de los bursts retenidos y registra la selección
%    mediante índices referidos a la campaña original.
%
%    Sintaxis:
%        data_clean = wsa_awac_clean(data_in)
%        data_clean = wsa_awac_clean(data_in, ...
%                                   'man', true, 'clean_idx', [1 2 10])
%
%    Argumento de entrada (requerido):
%        data_in - Struct de datos crudos generado por wsa_awac_read.
%                  También se contempla una ruta string o char a un NetCDF
%                  crudo compatible con wsa_awac_nc_read_raw. Consulte las
%                  limitaciones de esta reconstrucción en las notas.
%
%    Parámetros Nombre-Valor (opcionales):
%        'man'       true para selección manual; false para utilizar
%                    data.quality.summary.bad_bursts. Por defecto: false.
%        'clean_idx' Vector de índices de los bursts que se desean eliminar,
%                    referidos a la entrada antes de esta limpieza; no son
%                    los valores del contador del instrumento.
%                    Por defecto: []. Requerido y no vacío si man = true.
%                    Use enteros entre 1 y el número de bursts originales.
%
%    Argumento de salida:
%        data_clean - Copia del struct con whd y wad filtrados.
%            cleaning_status   true.
%            cleaning          Struct con:
%                Number_of_wave_measurements     Bursts retenidos.
%                Number_of_raw_wave_measurements Bursts de entrada.
%                time_start, time_end            Inicio del primer y último
%                                                burst retenidos (.whd).
%                cleaning_type                   'automatic' o 'manual'.
%                is_bad_burst                    Máscara sobre bursts de entrada.
%                bad_indices_raw                 Índices eliminados.
%                good_indices_raw                Índices retenidos.
%
%    Notas:
%    - En modo manual se eliminan exclusivamente clean_idx. Los bursts
%      marcados por QC no se eliminan adicionalmente de forma automática.
%    - quality se conserva en la dimensión original; no se recalculan sus
%      flags ni su resumen después de filtrar whd y wad.
%    - No se aceptan datos con cleaning_status = true. Debe quedar al menos
%      un burst: la función utiliza el primero y el último para sus fechas.
%    - Para el flujo v2.0.0 se recomienda utilizar el struct del lector.
%      La reconstrucción auxiliar desde NetCDF aún consulta atributos de
%      versiones anteriores, como wave_sampling_rate_Hz y Coordinate_system,
%      y no completa todos los metadatos necesarios para volver a exportar
%      con wsa_nc_write. La aceptación de una ruta no garantiza ese recorrido.
%    - La limpieza no modifica muestras, ni aplica correcciones o filtros.
%      Exporte el resultado con wsa_nc_write antes de wsa_nc_preprocess.
%
%    Ejemplo:
%        data = wsa_awac_read('C:\datos\AWAC');
%        data_clean = wsa_awac_clean(data, 'man', true, 'clean_idx', [1 2]);
%        wsa_nc_write(data_clean, 'awac_clean.nc', 'mounting_height', 0.50);
%        % Sustituir 0.50 por la altura real respecto al fondo.
%
%    See also wsa_awac_read, wsa_awac_nc_read_raw, wsa_nc_write.

% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 10/03/2026
% Fecha de modificación: 15/07/2026
% Revisión de documentación: 12/10/2026
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

bad_bursts = logical(bad_bursts(:));
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

% Banderas referidas a la dimensión original burst_raw
data_clean.cleaning.is_bad_burst = bad_bursts;

% Información adicional de la limpieza
data_clean.cleaning.Number_of_raw_wave_measurements = numel(bad_bursts);
data_clean.cleaning.bad_indices_raw = find(bad_bursts);
data_clean.cleaning.good_indices_raw = find(good_idx);

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