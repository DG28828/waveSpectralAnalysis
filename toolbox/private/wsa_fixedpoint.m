function [x, k, T] = wsa_fixedpoint(func, x0, tol, iterMax)
%fixedpoint - Método del punto fijo

%Calcula la solución x de la función f, dado un valor incial x0, una
%tolerancia tol y un número máximo de iteraciones iterMax

k = 0;
x = x0;
err = tol+1;
T(1,:) = [k x func(x) abs(x-func(x))];

while k < iterMax && err > tol
    x = func(x);
    err = abs(x-x0)/abs(x);
    x0 = x;
    k = k+1;
    T(k+1,:) = [k x func(x) err];
end
T = array2table(T, 'VariableNames',{'k', 'x', 'f(x)', 'err'});
end