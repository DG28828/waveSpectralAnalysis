function format_info = wsa_parse_hdr_data_format(hdr_txt, target_ext)
% Extrae del bloque "Data file format" la definición de columnas
% para un archivo específico (.whd, .wad, etc.)

    format_info = struct();
    format_info.file_ext = target_ext;
    format_info.columns = struct('index', {}, 'name', {}, 'unit', {});
    format_info.n_columns = 0;

    %----------------------------------------------------------------------
    % 1) Extraer sección completa "Data file format"
    %----------------------------------------------------------------------
    data_format_block = regexp(hdr_txt, ...
        'Data file format\s*[\r\n]+-+[\r\n]+([\s\S]*)$', ...
        'tokens', 'once');

    if isempty(data_format_block)
        error('No se encontró la sección "Data file format" en el archivo .hdr.');
    end

    data_format_block = data_format_block{1};

    %----------------------------------------------------------------------
    % 2) Buscar subbloque del archivo solicitado
    %----------------------------------------------------------------------
    expr = ['\[[^\]]*' regexptranslate('escape', target_ext) '\][\r\n]+([\s\S]*?)(?=[\r\n]+-+[\r\n]+\[[^\]]*\]|$)'];

    block = regexpi(data_format_block, expr, 'tokens', 'once');

    if isempty(block)
        error('No se encontró en el .hdr la definición de formato para %s.', target_ext);
    end

    block = block{1};

    %----------------------------------------------------------------------
    % 3) Parsear línea por línea
    %----------------------------------------------------------------------
    lines = regexp(block, '\r\n|\n|\r', 'split');

    col_count = 0;

    for i = 1:numel(lines)
        line = strtrim(lines{i});

        if isempty(line)
            continue
        end

        % Solo líneas que comienzan con índice entero
        tk = regexp(line, '^(\d+)\s+(.*)$', 'tokens', 'once');

        if isempty(tk)
            continue
        end

        idx = str2double(tk{1});
        rest = strtrim(tk{2});

        % Buscar unidad SOLO al final de la línea
        tk_unit = regexp(rest, '\(([^()]*)\)\s*$', 'tokens', 'once');

        if isempty(tk_unit)
            name = strtrim(rest);
            unit = '';
        else
            unit = strtrim(tk_unit{1});
            name = regexprep(rest, '\s*\([^()]*\)\s*$', '');
            name = strtrim(name);
        end

        col_count = col_count + 1;
        format_info.columns(col_count).index = idx;
        format_info.columns(col_count).name  = name;
        format_info.columns(col_count).unit  = unit;
    end

    format_info.n_columns = col_count;

    if format_info.n_columns == 0
        error('Se encontró el bloque de %s, pero no se pudieron extraer columnas.', target_ext);
    end
end