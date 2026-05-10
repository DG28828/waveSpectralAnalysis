function time_posix = wsa_datetime2posix(time)
% Convierte datetime MATLAB a segundos POSIX si es posible.
% Si no, devuelve NaN.
    time_posix = NaN;

    try
        if isa(time, 'datetime')
            if isempty(time.TimeZone)
                time.TimeZone = 'UTC';
            end
            time_posix = posixtime(time);
            return
        end
    catch
    end

    % Si por alguna razón viene como datenum numérico
    try
        if isnumeric(time) && isscalar(time)
            dt = datetime(time, 'ConvertFrom', 'datenum', 'TimeZone', 'UTC');
            time_posix = posixtime(dt);
            return
        end
    catch
    end
end