function wsa_nc_create_var(ncfile, varname, dims, datatype, varargin)
%wsa_nc_create_var Crea una variable netCDF y escribe sus atributos.
%
% Opciones reconocidas de nccreate:
%   DeflateLevel
%   Shuffle
%   ChunkSize
%   FillValue
%
% Los demás argumentos nombre-valor se escriben como atributos de la
% variable. Todos los atributos se escriben durante una sola apertura del
% archivo.

%% Normalizar entradas

ncfile   = char(string(ncfile));
varname  = char(string(varname));
datatype = char(string(datatype));

if mod(numel(varargin), 2) ~= 0
    error('WSA:InvalidNameValuePairs', ...
        'Los argumentos adicionales deben darse como pares nombre-valor.');
end

%% Separar opciones de nccreate y atributos

creationOptionNames = [
    "DeflateLevel"
    "Shuffle"
    "ChunkSize"
    "FillValue"
    ];

creationArgs  = {};
attributeArgs = {};

for k = 1:2:numel(varargin)

    name  = string(varargin{k});
    value = varargin{k+1};

    idx = find(strcmpi(name, creationOptionNames), 1);

    if ~isempty(idx)
        canonicalName = creationOptionNames(idx);

        creationArgs(end+1:end+2) = { ...
            char(canonicalName), value}; %#ok<AGROW>
    else
        attributeArgs(end+1:end+2) = { ...
            char(name), value}; %#ok<AGROW>
    end
end

%% Crear variable

%fprintf('[NETCDF] Definiendo: %s\n', varname);

%% Crear variable con reintentos

maxAttempts = 8;
created = false;

for attempt = 1:maxAttempts

    try

        if isfile(ncfile)

            nccreate(ncfile, ...
                varname, ...
                'Dimensions', dims, ...
                'Datatype', datatype, ...
                creationArgs{:});

        else

            nccreate(ncfile, ...
                varname, ...
                'Dimensions', dims, ...
                'Datatype', datatype, ...
                'Format', 'netcdf4', ...
                creationArgs{:});
        end

        created = true;
        break

    catch ME

        fprintf(['[NETCDF] Falló creación de "%s". ', ...
                 'Intento %d de %d.\n'], ...
                 varname, attempt, maxAttempts);

        if attempt == maxAttempts

            newME = MException( ...
                'WSA:NetCDFVariableCreationFailed', ...
                ['No fue posible crear la variable "%s" después ', ...
                 'de %d intentos en:\n%s\n\nCausa original:\n%s'], ...
                varname, ...
                maxAttempts, ...
                ncfile, ...
                getReport(ME, 'extended', 'hyperlinks', 'off'));

            newME = addCause(newME, ME);
            throwAsCaller(newME)
        end

        % Espera progresiva: 0.2, 0.4, ..., 1.4 s
        pause(0.20 * attempt);
    end
end

if ~created
    error('WSA:NetCDFVariableCreationFailed', ...
        'No fue posible crear la variable "%s".', varname);
end

%% Finalizar si no hay atributos

if isempty(attributeArgs)
    return
end

%% Abrir archivo para escritura con reintentos

maxAttempts = 6;
ncid = [];

for attempt = 1:maxAttempts

    try
        ncid = netcdf.open(ncfile, 'NC_WRITE');
        break

    catch ME

        if attempt == maxAttempts

            newME = MException( ...
                'WSA:NetCDFOpenFailed', ...
                ['No fue posible abrir el archivo después de %d intentos ', ...
                 'para escribir atributos de "%s":\n%s'], ...
                maxAttempts, varname, ncfile);

            newME = addCause(newME, ME);
            throwAsCaller(newME)
        end

        pause(0.10 * attempt);
    end
end

cleanupObj = onCleanup(@() safe_netcdf_close(ncid)); %#ok<NASGU>

%% Localizar grupo y variable

parts = strsplit(varname, '/');
parts = parts(~cellfun('isempty', parts));

groupID = ncid;

for k = 1:numel(parts)-1
    groupID = netcdf.inqNcid(groupID, parts{k});
end

variableName = parts{end};
variableID = netcdf.inqVarID(groupID, variableName);

%% Escribir todos los atributos en una misma apertura

try
    netcdf.reDef(ncid);

    for k = 1:2:numel(attributeArgs)

        attname  = attributeArgs{k};
        attvalue = attributeArgs{k+1};

        %fprintf('[NETCDF]   Atributo: %s\n', attname);

        netcdf.putAtt( ...
            groupID, ...
            variableID, ...
            attname, ...
            attvalue);
    end

    netcdf.endDef(ncid);
    netcdf.sync(ncid);
    netcdf.close(ncid);
    ncid = [];

catch ME

    newME = MException( ...
        'WSA:NetCDFAttributeWriteFailed', ...
        ['No fue posible escribir los atributos de la variable ', ...
         '"%s" en:\n%s'], ...
        varname, ncfile);

    newME = addCause(newME, ME);
    throwAsCaller(newME)
end

end


function safe_netcdf_close(ncid)

if isempty(ncid)
    return
end

try
    netcdf.close(ncid);
catch
    % Evitar que un error al cerrar oculte el error original.
end

end

