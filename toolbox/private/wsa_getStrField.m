function value = wsa_getStrField(txt, label)
    expr = [regexptranslate('escape', label), '\s+([^\r\n]+)'];
    tk = regexp(txt, expr, 'tokens', 'once');
    if isempty(tk)
        value = "";
    else
        value = string(strtrim(tk{1}));
    end
end