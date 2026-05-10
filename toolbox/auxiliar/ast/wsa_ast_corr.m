function out = wsa_ast_corr(ast1_raw, varargin)
%wsa_ast_corr - Corrección de señal AST (Acoustic Surface Tracking)
%
% Uso:
%   out = wsa_ast_corr(ast_raw, fs)
%   out = wsa_ast_corr(ast1_raw, ast2_raw, fs)
%
% Si se ingresan dos señales AST:
%   1) despiking individual
%   2) combinación AST1 + AST2
%   3) verificación por aceleración en señal combinada
%   4) separación nuevamente en AST1 y AST2
%   5) interpolación individual
%
% INPUT:
%   ast_raw : vector 
%   fs      : frecuencia de muestreo [Hz]
%
% OUTPUT:
%   ast_corr : señal corregida
%

%% Manejo de entradas

if nargin == 2
    mode = "single";
    fs = varargin{1};

elseif nargin == 3
    mode = "dual";
    ast2_raw = varargin{1};
    fs = varargin{2};

else
    error('Uso válido: wsa_ast_corr(ast_raw, fs) o wsa_ast_corr(ast1_raw, ast2_raw, fs).');
end

%% Verificaciones y cálculos iniciales

%Variables por defecto
g = 9.81; %m/s^2
sigma_max = 8;  %8 desviaciones estándar
sigma_min = 4;  %4 desviaciones estándar

% Formato de AST1
ast1 = ast1_raw(:);


% Formato de AST2, si existe
if mode == "dual"
    ast2 = ast2_raw(:);

    if isempty(ast1) || isempty(ast2)
        error('Las señales AST no pueden estar vacías.');
    end
else
    if isempty(ast1)
        error('La señal AST no puede estar vacía.');
    end
end

%% Despiking (eliminar picos con método de desviaciones estándar)

ast1_despike = wsa_ast_std_despike(ast1, sigma_max, sigma_min);

if mode == "dual"
    ast2_despike = wsa_ast_std_despike(ast2, sigma_max, sigma_min);
end

%% Verificación por aceleración

if mode == "single"
    [ast1_despike, acceleration, acc_idx] = wsa_ast_acc_despike(ast1_despike, fs, g);

else
    %Combinar señales AST
    out_comb = wsa_ast_combine(ast1_despike, ast2_despike, fs);
    ast_comb = out_comb.ast;
    fs_comb = out_comb.fs;
    
    %Verificación de aceleración a la señal combinada
    [~, acceleration_combined, acc_idx_combined] = wsa_ast_acc_despike(ast_comb, fs_comb, g);

    %Separar indices marcados en señal combinada
    [acc_idx_1, acc_idx_2] = split_combined_flags(acc_idx_combined, length(ast1_despike), length(ast2_despike), fs);
    ast1_despike(acc_idx_1) = NaN;
    ast2_despike(acc_idx_2) = NaN;

end


%% Interpolación de los datos marcados

if mode == "single"
    [ast_corr, NaN_idx, bad_detects, bad_detects_percentage] = interp_ast(ast1_despike, fs);

else
    [ast1_corr, NaN_idx_1, bad_detects_1, bad_detects_percentage_1] = interp_ast(ast1_despike, fs);
    [ast2_corr, NaN_idx_2, bad_detects_2, bad_detects_percentage_2] = interp_ast(ast2_despike, fs);

end

%% Guardar resultados

out = struct();
out.mode = mode;
out.fs = fs;

if mode == "single"
    out.ast_corr = ast_corr;
    out.bad_detects_flag = NaN_idx;
    out.bad_detects = bad_detects;
    out.bad_detects_percentage = bad_detects_percentage;
    out.acceleration = acceleration;
    out.acceleration_flag = acc_idx;

else
    out.ast_corr = [ast1_corr, ast2_corr];
    out.bad_detects_flag = [NaN_idx_1, NaN_idx_2];
    out.bad_detects = [bad_detects_1, bad_detects_2];
    out.bad_detects_percentage = [bad_detects_percentage_1, bad_detects_percentage_2];
    out.acceleration_flag = [acc_idx_1, acc_idx_2];

    out.acceleration_combined = acceleration_combined;
    out.acceleration_combined_flag = acc_idx_combined;
    out.fs_combined = 2*fs;

end



end



%% Funciones auxiliares

function [flag1, flag2] = split_combined_flags(flag_comb, N1, N2, fs)

dt = 1/fs;

t1 = (0:N1-1)' * dt;
t2 = (0:N2-1)' * dt + dt/2;

t_all = [t1; t2];
src_all = [ones(N1,1); 2*ones(N2,1)];
idx_all = [(1:N1)'; (1:N2)'];

[~, idx_sort] = sort(t_all);

src_sorted = src_all(idx_sort);
idx_sorted = idx_all(idx_sort);

flag1 = false(N1,1);
flag2 = false(N2,1);

bad_src = src_sorted(flag_comb);
bad_idx = idx_sorted(flag_comb);

flag1(bad_idx(bad_src == 1)) = true;
flag2(bad_idx(bad_src == 2)) = true;

end


function [ast_interp, NaN_idx, bad_detects, bad_detects_percentage] = interp_ast(ast, fs)

N = length(ast);
t = (0:N-1)'/fs;

NaN_idx = isnan(ast);           %Indices marcados con NaN
bad_detects = sum(NaN_idx);
bad_detects_percentage = 100*bad_detects/N;

if all(NaN_idx)
    warning('Todos los datos del AST fueron eliminados.');
    ast_interp = ast;

elseif any(NaN_idx)
    ast_interp = ast;
    ast_interp(NaN_idx) = interp1(t(~NaN_idx), ast(~NaN_idx), t(NaN_idx), 'linear', 'extrap');
else
    ast_interp = ast;
end

end