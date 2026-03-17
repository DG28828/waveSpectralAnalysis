function wsa_nc_create_var(ncfile, varname, dims, datatype, varargin)
    nccreate(ncfile, varname, ...
        'Dimensions', dims, ...
        'Datatype', datatype, ...
        'Format', 'netcdf4');

    for k = 1:2:numel(varargin)
        attname = varargin{k};
        attval  = varargin{k+1};
        ncwriteatt(ncfile, varname, attname, attval);
    end
end