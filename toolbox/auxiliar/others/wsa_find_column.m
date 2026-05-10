function idx = wsa_find_column(format_info, search_name)

idx = [];
names = string({format_info.columns.name});

% 1) Coincidencia exacta
exact_match = strcmpi(strtrim(names), strtrim(search_name));
if any(exact_match)
    idx = format_info.columns(find(exact_match, 1, 'first')).index;
    return
end

% 2) Coincidencia por prefijo/contenido
partial_match = contains(lower(names), lower(strtrim(search_name)));

if sum(partial_match) == 1
    idx = format_info.columns(find(partial_match, 1, 'first')).index;
elseif sum(partial_match) > 1
    error('La búsqueda de columna "%s" es ambigua en el formato del .hdr.', search_name);
end

end