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

omega = 2*pi*f(:);
k = zeros(size(omega));

mask = omega > 0;
if ~any(mask)
    return
end

w2 = omega(mask).^2;

x = w2/g;   %Aproximación inicial (relación dispersión agua profunda)

tol = 1e-10;
iterMax = 100;

for it = 1:iterMax
    kh = x * h;
    t = tanh(kh);
    sech2 = 1 - t.^2;   % más eficiente que sech(kh).^2

    % f(x) = g*x*tanh(x*h) - w^2
    fx = g*x.*t - w2;

    % f'(x) = g*(tanh(x*h) + x*h*sech^2(x*h))
    dfx = g*(t + kh.*sech2);

    dx = fx ./ dfx;
    x_new = x - dx;

    if all(abs(dx) <= tol * max(1, abs(x_new)))
        x = x_new;
        break
    end
    x = x_new;
end
k(mask) = x;

end