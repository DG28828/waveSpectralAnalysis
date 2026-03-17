function k = wsa_k(f, h, g)
%wsa_k - cálculo del número de onda mediante la relación de dispersión lineal.
%
%   Esta función calcula el número de onda k asociado a cada frecuencia f
%   resolviendo la relación de dispersión lineal para ondas de gravedad en
%   profundidad finita:
%
%       ω^2 = gk tanh(kh)
%
%   La ecuación se resuelve numéricamente mediante el método de 
%   Newton-Raphson.
%
%
%   Sintaxis:
%       k = wsa_k(f, h, g) calcula el número de onda k para cada frecuencia
%           contenida en el vector f.
%
%
%   Argumentos de entrada (requeridos):
%       f       - Frecuencias físicas.
%                   Vector (Hz).
%
%       h       - Profundidad del agua.
%                   Escalar positivo (m).
%
%       g       - Aceleración gravitacional.
%                   Escalar positivo (m/s^2).
%
%
%   Parámetros Nombre-Valor (opcionales):
%       (Esta función no posee parámetros opcionales.)
%
%
%   Argumentos de salida:
%   k           - Número de onda asociado a cada frecuencia.
%                   Vector (rad/m).
%
%
%   Notas:
%   • Para f = 0 se asigna k = 0 directamente.
%   • Como aproximación inicial se emplea la solución de agua profunda:
%
%         k0 = ω^2 / g
%
%   • La solución se obtiene mediante el método de Newton-Raphson,
%     utilizando una tolerancia de 1e-5 y un máximo de 1000 iteraciones.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 11/02/2026
% Fecha de modificación: 20/02/2026
% -------------------------------------------------------------------------

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