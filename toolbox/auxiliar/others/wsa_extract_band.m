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

    %% Verificaciones iniciales

    f = f(:);

    fmin_req = limits(1);
    fmax_req = limits(2);

    fmin = fmin_req;
    fmax = fmax_req;  

    if numel(limits) ~= 2 || ~isnumeric(limits)
        error('limits debe ser un vector numérico [fmin, fmax].');
    end

    if ~isfinite(fmin) || ~isfinite(fmax) || fmin >= fmax
        error('Los límites deben ser finitos y cumplir fmin < fmax.');
    end

    if any(diff(f) <= 0)
        error('El vector f debe ser estrictamente creciente.');
    end

    %% Ajustar límites 

    % Espaciamiento en los extremos de la malla.
    df_lower = f(2) - f(1);
    df_upper = f(end) - f(end - 1);

    % Tolerancia para errores de punto flotante.
    tolerance = 100*eps(max(1, max(abs(f))));

    % Ajustar el límite inferior cuando queda como máximo un bin fuera.
    if fmin < f(1)

        lower_difference = f(1) - fmin;

        if lower_difference <= df_lower + tolerance
            fmin = f(1);
        else
            error('El límite inferior %.9g Hz está fuera del intervalo disponible [%.9g, %.9g] Hz.', fmin_requested, f(1), f(end));
        end
    end

    % Ajustar el límite superior cuando queda como máximo un bin fuera.
    if fmax > f(end)

        upper_difference = fmax - f(end);

        if upper_difference <= df_upper + tolerance
            fmax = f(end);
        else
            error('El límite superior %.9g Hz está fuera del intervalo disponible [%.9g, %.9g] Hz.', fmax_requested, f(1), f(end));
        end
    end

    if fmin >= fmax
        error('Después de ajustar los límites al intervalo disponible, la banda resultante no es válida: [%.9g, %.9g] Hz.', fmin, fmax);
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