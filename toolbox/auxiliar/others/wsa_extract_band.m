function [f_band, X_band] = wsa_extract_band(f, X, limits)
%wsa_extract_band Extrae una banda según límites.
%
%   [f_band, X_band] = wsa_extract_band(f, X, limits)
%
%   Entradas:
%       f       : vector de frecuencias.
%       X       : vector asociado a f. Puede estar vacío.
%       limits  : límites de la banda [fmin, fmax].
%
%   Salidas:
%       f_band  : vector de frecuencias de la banda.
%       X_band  : valores de X dentro de la banda.

    %% Preparar entradas

    f = f(:);

    fmin = limits(1);
    fmax = limits(2);

    %% Verificaciones iniciales

    if numel(limits) ~= 2 || ~isnumeric(limits)
        error('limits debe ser un vector numérico [fmin, fmax].');
    end

    if ~isfinite(fmin) || ~isfinite(fmax) || fmin >= fmax
        error('Los límites deben ser finitos y cumplir fmin < fmax.');
    end

    if any(diff(f) <= 0)
        error('El vector f debe ser estrictamente creciente.');
    end

    if fmin < f(1) || fmax > f(end)
        error('La banda [%.6g, %.6g] Hz está fuera del intervalo disponible [%.6g, %.6g] Hz.', fmin, fmax, f(1), f(end));
    end

    %% Frecuencias interiores

    mask = (f > fmin) & (f < fmax);

    f_band = [fmin; f(mask); fmax];

    %% Extraer e interpolar X

    if isempty(X)
        warning('El vector de entrada no tiene valores; se establece la banda vacía.');
        X_band = [];
        return
    end

    if ~isvector(X)
        error('X debe ser un vector.');
    end

    X = X(:);

    if numel(X) ~= numel(f)
        error('f y X deben tener la misma cantidad de elementos.');
    end

    % Interpolación lineal en los límites exactos de la banda.
    X_band = interp1(f, X, f_band, 'linear');

end