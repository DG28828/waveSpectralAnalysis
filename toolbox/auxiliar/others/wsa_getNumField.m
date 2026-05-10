function value = wsa_getNumField(txt, label)
    expr = [label, '\s+([-\d\.]+)'];
    tk = regexp(txt, expr, 'tokens', 'once');
    if isempty(tk)
        value = NaN;
    else
        value = str2double(tk{1});
    end
end