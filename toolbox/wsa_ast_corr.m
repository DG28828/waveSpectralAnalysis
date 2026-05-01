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
%   ast_raw : señal AST (vector)
%   fs      : frecuencia de muestreo [Hz]
%
% OUTPUT:
%   ast_corr : señal corregida

%% Verificaciones y cálculos iniciales

%Variables por defecto
g = 9.81; %m/s^2

%Convertir a vector columna
ast = ast_raw(:);

N = length(ast);
t = (0:N-1)'/fs;

%% Despiking (eliminar picos con método de desviaciones estándar)
ast_despike = ast;

sigma_max = 8;
sigma_min = 4;

for k = sigma_max:-1:sigma_min
    mu = mean(ast_despike, 'omitnan');      % Media de la señal
    sigma = std(ast_despike, 'omitnan');    % Desviación estándar de la señal

    out_idx = abs(ast_despike - mu) > k*sigma;  % Indices de datos mayores a k desviaciones estándar

    ast_despike(out_idx) = NaN;             % Se marcan los datos malos como NaN
end

%% Verificación por aceleración
dt = 1/fs;

%Estimación de la aceleración de la señal (segunda derivada)
acc = diff(ast_despike, 2)/dt^2;
acceleration = NaN(size(ast_despike));
acceleration(2:end-1) = acc;            %Centrar la señal de aceleración

%Marcar datos con aceleración mayor a g = 9.81m/s^2
acc_idx = abs(acceleration) > g;
ast_despike(acc_idx) = NaN;


%% Interpolación de los datos marcados
NaN_idx = isnan(ast_despike);           %Indices marcados con NaN
bad_detects = sum(NaN_idx);
bad_detects_percentage = 100*bad_detects/N;

if any(~NaN_idx)
    %Se ejecuta si hay datos resultantes que no sean NaN
    ast_interp = ast_despike;
    ast_interp(NaN_idx) = interp1(t(~NaN_idx), ast_despike(~NaN_idx), t(NaN_idx), 'linear', 'extrap');
else
    %Se ejecuta si todos los datos son NaN
    warning('Todos los datos del registro de AST fueron eliminados.');
    ast_interp = ast_despike;
end

ast_corr = ast_interp;

%% Guardar resultados
out.ast_corr = ast_corr;
out.bad_detects_flag = NaN_idx;
out.bad_detects = bad_detects;
out.bad_detects_percentage = bad_detects_percentage;



end