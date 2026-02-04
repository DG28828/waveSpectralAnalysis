function [D, theta] = wsa_dirmem(a1, a2, b1, b2, Ntheta)
%wsa_dirmem - método de máxima entropía para distribución direccional
%
%   Esta función emplea el método de máxima entropía (MEM) para determinar
%   la distribución direccional de señales de mar a partir de los
%   coeficientes de la serie de Fourier. El método empleado es el
%   desarrollado por (Lygre & Krogstad, 1986) en su artículo "Maximum
%   Entropy Estimation of the Directional Distribution in Ocean Wave
%   Spectra".
%
%   Sintaxis:
%
%
%   Argumentos de entrada:
%       a1 - primeros coeficiente de la serie de Fourier (d1 de (Lygre & Krogstad, 1986)
%           vector
%       a2 - segundos coeficiente de la serie de Fourier (d2 de (Lygre & Krogstad, 1986)
%           vector
%       b1 - terceros coeficiente de la serie de Fourier (d3 de (Lygre & Krogstad, 1986)
%           vector
%       b2 - cuartos coeficiente de la serie de Fourier (d4 de (Lygre & Krogstad, 1986)
%           vector
%
%   Argumentos de salida:
%       D - Valores de distribución direccional
%           vector
%       theta - Angulos
%           vector
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 03/02/2026
% -------------------------------------------------------------------------

%% Cálculo de la distribución direccional
%   Se emplea la misma notación que en (Lygre & Krogstad, 1986).

d1 = a1;
d2 = a2;
d3 = b1;
d4 = b2;

C1 = d1 + 1i*d2;
C2 = d3 + 1i*d4;

if any(abs(C1).^2 + abs(C2).^2 >= 1)
    warning('Coeficientes fuera del dominio de validez del MEM: |C1|^2+|C2| >= 1');
end

phi1 = (C1 - conj(C1).*C2)./(1 - abs(C1).^2);
phi2 = C2 - C1.*phi1;

%Se crea vector de angulos
theta = linspace(0, 2*pi, Ntheta);

%Se calcula la distribución direccional
num_D = (1 - phi1.*conj(C1) - phi2.*conj(C2));
den_D = ((2*pi).*abs(1 - phi1.*exp(-1i*theta) - phi2.*exp(-2*1i*theta) ).^2); 
D = num_D./den_D;

% Operaciones finales sobre D

%   Se debe tomar solo la parte real, D teóricamente es real, pero pueden
%   quedar números complejos muy pequeños debido al cálculo numérico.
D = real(D);

%   Normalizar la distribución, el área bajo la curva debe ser unitaria
for k = 1:size(D, 1)
    D(k, :) = D(k, :)./trapz(theta, D(k, :));
end

end