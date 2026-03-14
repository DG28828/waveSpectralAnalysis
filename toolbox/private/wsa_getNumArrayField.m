function value = wsa_getNumArrayField(txt, label)
    expr = [label, '\s+([-\d\., ]+)'];
    tk = regexp(txt, expr, 'tokens', 'once');
    if isempty(tk)
        value = [];
    else
        raw = strrep(strtrim(tk{1}), ',', ' ');
        value = sscanf(raw, '%f')';
    end
end