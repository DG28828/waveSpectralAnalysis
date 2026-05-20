function wsa_nc_create_var(ncfile, varname, dims, datatype, varargin)
%wsa_nc_create_var - Crea una variable NetCDF y escribe sus atributos.
%
% La función permite la creación de una variable NetCDF, escribir atributos
% y además utilizar opciones propias de nccreate.
%
% Opciones habilitadas de nccreate:
%   'DeflateLevel'
%   'Shuffle'
%   'ChunkSize'
%   'FillValue'
%
% Los parámetros que no correspondan a estas opciones serán tomados como
% atributos de la variable.

    % Opciones de creación reconocidas por nccreate
    nccreate_opts = {};
    att_opts      = {};

    valid_nccreate_opts = {'DeflateLevel', 'Shuffle', 'ChunkSize', 'FillValue'};

    for k = 1:2:numel(varargin)
        name = varargin{k};
        val  = varargin{k+1};

        if any(strcmpi(name, valid_nccreate_opts))
            nccreate_opts = [nccreate_opts, {name, val}];
        else
            att_opts = [att_opts, {name, val}];
        end
    end

    nccreate(ncfile, varname, ...
        'Dimensions', dims, ...
        'Datatype', datatype, ...
        'Format', 'netcdf4', ...
        nccreate_opts{:});

    for k = 1:2:numel(att_opts)
        attname = att_opts{k};
        attval  = att_opts{k+1};
        ncwriteatt(ncfile, varname, attname, attval);
    end
end