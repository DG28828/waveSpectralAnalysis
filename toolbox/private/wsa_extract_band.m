function [f_band, S_band] = wsa_extract_band(f, S, limits)
%Extraer los valores de f y S correspondientes a los límites fmin y fmax de
%la banda indicada

    fmin = limits(1);
    fmax = limits(2);

    mask = (f > fmin) & (f <= fmax);

    f_band = f(mask);
    S_band = S(mask);
end