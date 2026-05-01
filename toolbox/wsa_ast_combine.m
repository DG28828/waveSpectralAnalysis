function out = wsa_ast_combine(ast1, ast2, fs)
%wsa_combine_ast - Combina dos señales AST intercaladas
%
% Permite combinar señales AST muestreadas a fs (1 Hz o 2 Hz)
% para generar una señal equivalente a 2*fs (2 Hz o 4 Hz).
%
% INPUT:
%   ast1 : señal AST1 (t = 0, 1/fs, 2/fs, ...)
%   ast2 : señal AST2 (t = 1/(2fs), 3/(2fs), ...)
%   fs   : frecuencia de muestreo original [Hz]
%
% OUTPUT:
%   out.ast     : señal combinada
%   out.fs      : frecuencia de muestreo resultante (= 2*fs)

%% Validaciones
if nargin < 3
    error('Se debe especificar fs de las señales AST individuales');
end

if isempty(ast1) || isempty(ast2)
    error('Las señales no pueden estar vacías');
end

%% Convertir a columna
ast1 = ast1(:);
ast2 = ast2(:);

N1 = length(ast1);
N2 = length(ast2);

%% Construcción de vectores de tiempo
dt = 1/fs;

t1 = (0:N1-1)' * dt;              % AST1
t2 = (0:N2-1)' * dt + dt/2;       % AST2 (desfasada)

%% Unir y ordenar
t_all = [t1; t2];
ast_all = [ast1; ast2];

[~, idx] = sort(t_all);
ast = ast_all(idx);
fs_out = 2*fs;

%% Guardar resultados
out = struct;
out.ast = ast;
out.fs = fs_out;

end