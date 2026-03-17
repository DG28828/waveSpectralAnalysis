function value = wsa_getTextField(txt, label)
    expr = [label, '\s+([^\r\n]+)'];
    tk = regexp(txt, expr, 'tokens', 'once');
    if isempty(tk)
        value = "";
    else
        value = string(strtrim(tk{1}));
    end
end