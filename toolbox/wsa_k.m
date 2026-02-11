function k = wsa_k(f, h, g)


%Estimación de k para cada frecuencia f
k = zeros(size(f));
tol = 1e-5;
iterMax = 1000;
for i = 1:length(f)
    omega_i = 2*pi*f(i);    %Convertir f a omega

    %Caso: omega = 0:
    if omega_i == 0
        k(i) = 0;
        continue
    end

    func = @(k) omega_i^2 - g*k.*tanh(k*h);             %Función
    dfunc = @(k) -g.*tanh(k*h) - g*k*h.*sech(k*h).^2;   %Derivada
    k0 = omega_i^2/g;   %Aproximación inicial (relación dispersión agua profunda)
    k(i) = wsa_newraph(func, dfunc, k0, tol, iterMax);  %Método de Newton-Raphson
end