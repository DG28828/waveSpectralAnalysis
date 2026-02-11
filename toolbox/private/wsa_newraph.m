function [x, k, T] = wsa_newraph(f, df, x0, tol, iterMax)
k = 0;
x = x0;
err = tol+1;
%x1 = x0-f(x0)/df(x0);
T = [];
%T(1,:) = [k+1 x0  x1 abs(x-x1)/abs(x1)];

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