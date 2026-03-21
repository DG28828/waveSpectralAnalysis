function bands = wsa_validate_band_struct(bands, struct_name)
    fn = fieldnames(bands);
    for i = 1:numel(fn)
        val = bands.(fn{i});
        if ~wsa_is_valid_band(val)
            error(['El campo "%s" de %s debe ser un vector numérico [fmin fmax] ', ...
                   'finito y con fmin < fmax.'], fn{i}, struct_name);
        end
    end
end