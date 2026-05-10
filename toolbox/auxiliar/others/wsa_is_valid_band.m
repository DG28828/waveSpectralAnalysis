function tf = wsa_is_valid_band(x)
    tf = isnumeric(x) && numel(x) == 2 && all(isfinite(x)) && x(1) < x(2);
end

