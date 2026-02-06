function [out, info] = wsa_dirmem(a1, b1, a2, b2, Ntheta, varargin)
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
%       a1 - primer coeficiente de la serie de Fourier (d1 de (Lygre & Krogstad, 1986)
%           vector
%       b1 - segundo coeficiente de la serie de Fourier (d2 de (Lygre & Krogstad, 1986)
%           vector
%       a2 - tercer coeficiente de la serie de Fourier (d3 de (Lygre & Krogstad, 1986)
%           vector
%       b2 - cuarto coeficiente de la serie de Fourier (d4 de (Lygre & Krogstad, 1986)
%           vector
%
%   Argumentos de salida:
%       out - Salidas numéricas | struct
%           D - Distribución direccional normalizada [1 / rad]
%               vector
%           theta - Angulos [rad]
%               vector
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 04/02/2026
% -------------------------------------------------------------------------

%% Cálculo de la distribución direccional
%   Se emplea la misma notación que en (Lygre & Krogstad, 1986).

d1 = a1;
d2 = b1;
d3 = a2;
d4 = b2;

C1 = d1 + 1i*d2;
C2 = d3 + 1i*d4;

phi1 = (C1 - conj(C1).*C2)./(1 - abs(C1).^2);
phi2 = C2 - C1.*phi1;

%Se crea vector de angulos
theta = linspace(0, 2*pi, Ntheta+1);
theta(end) = []; %Excluir el ultimo dato porque 2pi = 0

%Se calcula la distribución direccional
num_D = (1 - phi1.*conj(C1) - phi2.*conj(C2));
den_D = ((2*pi).*abs(1 - phi1.*exp(-1i*theta) - phi2.*exp(-2*1i*theta) ).^2); 
D = num_D./(den_D);

%%%%%%%% Operaciones finales sobre D %%%%%%%%%

% 1) Se debe tomar solo la parte real, D teóricamente es real, pero pueden
%    quedar números complejos muy pequeños debido al cálculo numérico.
D = real(D);
tol = 1e-12;
D_is_pos = all(D(:) >= -tol); %Verificar que D es positivo (teoricamente debe cumplirse)

% 2) Normalizar la distribución, el área bajo la curva debe ser unitaria
for k = 1:size(D, 1)
    D(k, :) = D(k, :)./trapz(theta, D(k, :));
end

%Struct para resultados
out = struct;
out.D = D;
out.theta = theta;

% Otras salidas que podrían ser de interés
out.mem_params.C1 = C1;
out.mem_params.C2 = C2;
out.mem_params.phi1 = phi1;
out.mem_params.phi2 = phi2;

% Información %Documentar esto!!
info.D_is_pos = D_is_pos;
info.min_D_value = min(D(:));


end