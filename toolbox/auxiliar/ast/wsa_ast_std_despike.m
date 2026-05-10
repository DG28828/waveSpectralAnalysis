function ast_despike = wsa_ast_std_despike(ast, sigma_max, sigma_min)

ast_despike = ast;

for k = sigma_max:-1:sigma_min

    mu = mean(ast_despike, 'omitnan');              % Media de la señal
    sigma = std(ast_despike, 'omitnan');            % Desviación estándar de la señal

    out_idx = abs(ast_despike - mu) > k.*sigma;     % Indices de datos mayores a k desviaciones estándar

    ast_despike(out_idx) = NaN;                     % Se marcan los datos malos como NaN
end

end