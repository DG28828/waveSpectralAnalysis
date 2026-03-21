function [f_band, X_band] = wsa_extract_band(f, X, limits)
%Extraer los valores de f y X correspondientes a los límites fmin y fmax de
%la banda indicada

    fmin = limits(1);
    fmax = limits(2);

    mask = (f > fmin) & (f <= fmax);

    f_band = f(mask);

    if ~isempty(X)
        X_band = X(mask);
    else 
        warning('El vector de entrada no tiene valores, estableciendo banda vacía')
        X_band = [];
end