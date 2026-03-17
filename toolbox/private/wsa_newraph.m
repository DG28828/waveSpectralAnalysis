function [x, k, T] = wsa_newraph(f, df, x0, tol, iterMax)
%wsa_newraph - método de Newton-Raphson para búsqueda de raíces.
%
%   Esta función implementa el método iterativo de Newton-Raphson para 
%   encontrar una raíz de una función no lineal f(x), dada su derivada df(x)
%   y un valor inicial x0.
%
%
%   Sintaxis:
%       x = wsa_newraph(f, df, x0, tol, iterMax) estima la raíz de la
%           función f utilizando el método de Newton-Raphson.
%
%       [x, k, T] = wsa_newraph(f, df, x0, tol, iterMax) devuelve
%           adicionalmente el número de iteraciones realizadas y una tabla
%           con el historial del proceso iterativo.
%
%
%   Argumentos de entrada (requeridos):
%       f       - Función cuya raíz se desea encontrar.
%                   Function handle.
%
%       df      - Derivada de la función f.
%                   Function handle.
%
%       x0      - Valor inicial.
%                   Escalar.
%
%       tol     - Tolerancia de convergencia.
%                   Escalar positivo.
%
%       iterMax - Número máximo de iteraciones permitidas.
%                   Entero positivo.
%
%
%   Parámetros Nombre-Valor (opcionales):
%       (Esta función no posee parámetros opcionales.)
%
%
%   Argumentos de salida:
%   x           - Raíz estimada de la función.
%                   Escalar.
%
%   k           - Número de iteraciones realizadas.
%
%   T           - Tabla con el historial iterativo:
%                   k     - Iteración
%                   x0    - Valor en la iteración anterior
%                   x     - Nuevo valor estimado
%                   err   - Error relativo
%
%
%   Notas:
%   • El criterio de convergencia se basa en el error relativo:
%
%         err = |x - x0| / |x|
%
%     deteniéndose cuando err < tol o cuando se alcanza iterMax.
%   • Si la derivada se anula durante el proceso iterativo,
%     el algoritmo se detiene.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 11/01/2026
% Fecha de modificación: 20/02/2026
% -------------------------------------------------------------------------

k = 0;
x = x0;
err = tol+1;
T = [];

while k < iterMax && err >= tol
    q = df(x);
    if q==0
        disp('Se anula la derivada')
        return
    end
    x = x-f(x)/q;
    err = abs(x-x0)/abs(x);
    T(k+1,:) = [k+1 x0 x err];
    x0 = x;
    k = k+1;
    
end
T = array2table(T, 'VariableNames',{'k', 'x0', 'x', 'err'});
end