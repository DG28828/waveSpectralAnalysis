function col = wsa_extract_column(M, format_info, search_name, file_label)
% Extrae una columna usando el nombre definido en el .hdr

    idx = wsa_find_column(format_info, search_name);
    
    if isempty(idx)
        error('No se encontró la columna "%s" en la definición del archivo %s del .hdr.', ...
            search_name, file_label);
    end
    
    if idx > size(M,2)
        error(['La columna "%s" está definida como columna %d en %s, ' ...
               'pero el archivo solo tiene %d columnas.'], ...
               search_name, idx, file_label, size(M,2));
    end
    
    col = M(:, idx);
end