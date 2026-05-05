function out = wsa_ast_corr(ast_raw, fs)
%wsa_ast_corr - Corrección de señal AST (Acoustic Surface Tracking)
%
% Aplica:
%   1) Despiking iterativo por desviación estándar (8 desviaciones estándar a 4 desviaciones estándar)
%   2) Corrección física por aceleración
%   3) Interpolación de datos eliminados
%   4) Detrend lineal final
%
% INPUT:
%   ast_raw : vector o matriz [muestras x estados_de_mar]
%   fs      : frecuencia de muestreo [Hz]
%
% OUTPUT:
%   ast_corr : señal corregida
%


%% Verificaciones y cálculos iniciales

%Variables por defecto
g = 9.81; %m/s^2
sigma_max = 8;  %8 desviaciones estándar
sigma_min = 4;  %4 desviaciones estándar

%Verificar y aplicar formato correcto a los datos
ast = squeeze(ast_raw);
if isvector(ast)
    ast = ast(:);
end

[N, nBursts] = size(ast);
dt = 1/fs;
t = (0:N-1)'/fs;

%% Despiking (eliminar picos con método de desviaciones estándar)
ast_despike = ast;

for k = sigma_max:-1:sigma_min

    mu = mean(ast_despike, 1, 'omitnan');           % Media de la señal
    sigma = std(ast_despike, 0, 1, 'omitnan');      % Desviación estándar de la señal

    out_idx = abs(ast_despike - mu) > k.*sigma;     % Indices de datos mayores a k desviaciones estándar

    ast_despike(out_idx) = NaN;                     % Se marcan los datos malos como NaN
end

%% Verificación por aceleración

%Estimación de la aceleración de la señal (segunda derivada)
acc = diff(ast_despike, 2, 1)/dt^2;
acceleration = NaN(size(ast_despike));
acceleration(2:end-1, :) = acc;            %Centrar la señal de aceleración

%Marcar datos con aceleración mayor a g = 9.81m/s^2
acc_idx = abs(acceleration) > g;
ast_despike(acc_idx) = NaN;


%% Interpolación de los datos marcados
NaN_idx = isnan(ast_despike);           %Indices marcados con NaN
bad_detects = sum(NaN_idx, 1);
bad_detects_percentage = 100*bad_detects/N;

ast_corr = NaN(size(ast_despike));

for j = 1:nBursts
    y = ast_despike(:,j);
    idx_nan = isnan(y);

    if all(idx_nan)
        warning('Todos los datos del AST fueron eliminados en el estado de mar %d.', j);
        ast_corr(:,j) = y;

    elseif any(idx_nan)
        ast_corr(:,j) = y;
        ast_corr(idx_nan,j) = interp1(t(~idx_nan), y(~idx_nan), t(idx_nan), 'linear', 'extrap');
    else
        ast_corr(:,j) = y;
    end


%% Guardar resultados
out.ast_corr = ast_corr;
out.bad_detects_flag = NaN_idx;
out.bad_detects = bad_detects;
out.bad_detects_percentage = bad_detects_percentage;



end