function [out, info] = wsa_dirmem(a1, b1, a2, b2, Ntheta, varargin)
%wsa_dirmem - método de máxima entropía para distribución direccional.
%
%   Esta función emplea el método de máxima entropía (MEM) para determinar
%   la distribución direccional D(θ) del oleaje a partir de los primeros
%   cuatro coeficientes de la serie de Fourier.
%
%   El método implementado corresponde al desarrollado por
%   (Lygre & Krogstad, 1986) en su artículo:
%   "Maximum Entropy Estimation of the Directional Distribution in Ocean
%   Wave Spectra".
%
%
%   Sintaxis:
%       out = wsa_dirmem(a1, b1, a2, b2, Ntheta)
%           estima la distribución direccional normalizada.
%
%       [out, info] = wsa_dirmem(a1, b1, a2, b2, Ntheta)
%           devuelve adicionalmente información diagnóstica del cálculo.
%
%
%   Argumentos de entrada (requeridos):
%       a1      - Primer coeficiente de Fourier.
%                   Vector.
%
%       b1      - Segundo coeficiente de Fourier.
%                   Vector.
%
%       a2      - Tercer coeficiente de Fourier.
%                   Vector.
%
%       b2      - Cuarto coeficiente de Fourier.
%                   Vector.
%
%       Ntheta  - Número de divisiones angulares para discretizar
%                   el intervalo [0, 2π).
%                   Escalar entero positivo.
%
%
%   Parámetros Nombre-Valor (opcionales):
%       (No definidos actualmente)
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       D           - Distribución direccional normalizada [1/rad]
%                       Matriz (frecuencia × dirección).
%
%       theta       - Vector de ángulos [rad] en el intervalo [0, 2π).
%
%       mem_params  - Parámetros internos del método:
%                       C1, C2, phi1, phi2
%
%   info        - Información diagnóstica:
%       D_is_pos       - true si D ≥ 0 (dentro de tolerancia numérica)
%       min_D_value    - Valor mínimo de D
%
%
%   Notas:
%   • Se utiliza la misma notación compleja que en (Lygre & Krogstad, 1986):
%
%         C1 = a1 + i b1
%         C2 = a2 + i b2
%
%     y los parámetros:
%
%         φ1 = (C1 − C1* C2) / (1 − |C1|²)
%         φ2 = C2 − C1 φ1
%
%   • La distribución direccional se calcula como:
%
%         D(θ) = (1 − φ1 C1* − φ2 C2*) /
%                (2π |1 − φ1 e^(−iθ) − φ2 e^(−2iθ)|²)
%
%   • Teóricamente D(θ) es real y no negativa. Sin embargo, pueden
%     aparecer pequeñas partes imaginarias debido a errores numéricos,
%     por lo que se conserva únicamente la parte real.
%
%   • La distribución se normaliza de modo que:
%
%         ∫₀²π D(θ) dθ = 1
%
%   • El último punto θ = 2π se excluye para evitar duplicidad con θ = 0.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 03/02/2026
% Fecha de modificación: 20/02/2026
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
tol = 1e-4;
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