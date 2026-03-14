function value = wsa_getDateField(txt, label)
    expr = [label, '\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2}:[0-9]{2})'];
    tk = regexp(txt, expr, 'tokens', 'once');
    if isempty(tk)
        value = NaT;
    else
        value = datetime(tk{1}, 'InputFormat', 'dd/MM/yyyy HH:mm:ss');
    end
end