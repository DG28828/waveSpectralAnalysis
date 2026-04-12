function out = wsa_dir_TFS(a1, b1, Ntheta, varargin)
%wsa_dir_TFS Reconstruye la distribucion direccional mediante serie de Fourier truncada (Truncated Fourier Series).
%
% Sintaxis
%   out = wsa_dir_Fourier(a1, b1, Ntheta)
%   out = wsa_dir_Fourier(a1, b1, Ntheta, a2, b2)
%
% Descripcion
%   Reconstruye la distribucion direccional D(theta) para cada frecuencia
%   a partir de coeficientes de Fourier direccionales.
%
%   Si solo se especifican a1 y b1, se emplea una reconstruccion con
%   primer armonico:
%
%       D(theta) = 1/(2*pi) * [1 + 2*a1*cos(theta) + 2*b1*sin(theta)]
%
%   Si ademas se especifican a2 y b2, se emplea una reconstruccion con
%   segundo armonico:
%
%       D(theta) = 1/(2*pi) * [1 + 2*a1*cos(theta) + 2*b1*sin(theta) ...
%                                + 2*a2*cos(2*theta) + 2*b2*sin(2*theta)]
%
%   Posteriormente, para cada frecuencia:
%       1) Se toma solo la parte positiva de D
%       2) Se normaliza para que el area bajo la curva sea unitaria
%
% Argumentos de entrada
%   a1      : Vector columna o fila [nf x 1] o [1 x nf] con coeficiente a1
%   b1      : Vector columna o fila [nf x 1] o [1 x nf] con coeficiente b1
%   Ntheta  : Numero de divisiones angulares
%
% Argumentos opcionales
%   a2      : Vector con coeficiente a2
%   b2      : Vector con coeficiente b2
%
% Argumentos de salida
%   out     : Estructura con campos:
%       theta   -> vector angular [1 x Ntheta] en radianes
%       D       -> distribucion direccional [nf x Ntheta]
%       order   -> orden de reconstruccion empleado (1 o 2)
%
% Notas
%   - theta se define en [0, 2*pi), excluyendo el ultimo punto para evitar
%     duplicar 0 y 2*pi.
%   - La truncacion de la serie puede generar valores negativos, por lo que
%     se recorta a valores no negativos antes de normalizar.

%% Manejo de entradas

if ~(isvector(a1) && isvector(b1))
    error('wsa_dir_Fourier:InvalidInput', ...
        'a1 y b1 deben ser vectores.');
end

a1 = a1(:);
b1 = b1(:);

if length(a1) ~= length(b1)
    error('wsa_dir_Fourier:SizeMismatch', ...
        'a1 y b1 deben tener la misma longitud.');
end

if ~isscalar(Ntheta) || Ntheta <= 0 || mod(Ntheta,1) ~= 0
    error('wsa_dir_Fourier:InvalidNtheta', ...
        'Ntheta debe ser un entero positivo.');
end

use_second_order = false;

if isempty(varargin)
    % Solo a1 y b1
    use_second_order = false;

elseif length(varargin) == 2
    % a1, b1, a2, b2
    a2 = varargin{1};
    b2 = varargin{2};

    if ~(isvector(a2) && isvector(b2))
        error('wsa_dir_Fourier:InvalidInput', ...
            'a2 y b2 deben ser vectores.');
    end

    a2 = a2(:);
    b2 = b2(:);

    if length(a2) ~= length(a1) || length(b2) ~= length(a1)
        error('wsa_dir_Fourier:SizeMismatch', ...
            'a2 y b2 deben tener la misma longitud que a1 y b1.');
    end

    use_second_order = true;

else
    error('wsa_dir_Fourier:InvalidOptionalInputs', ...
        'Debe especificar o bien solo a1 y b1, o bien a1, b1, a2 y b2.');
end

%% Se crea vector de angulos

theta = linspace(0, 2*pi, Ntheta+1);
theta(end) = []; % Excluir el ultimo dato porque 2*pi = 0

nf = length(a1);
nt = length(theta);

D = zeros(nf, nt);

%% Reconstruccion de D

for i = 1:nf

    if use_second_order
        D(i,:) = (1/(2*pi)) * ( ...
            1 ...
            + 2*a1(i)*cos(theta) ...
            + 2*b1(i)*sin(theta) ...
            + 2*a2(i)*cos(2*theta) ...
            + 2*b2(i)*sin(2*theta) );
    else
        D(i,:) = (1/(2*pi)) * ( ...
            1 ...
            + 2*a1(i)*cos(theta) ...
            + 2*b1(i)*sin(theta) );
    end

end

%%%%%%%% Operaciones finales sobre D %%%%%%%%%

% 1) Se debe tomar solo la parte positiva.
% 2) Normalizar la distribucion, el area bajo la curva debe ser unitaria
for k = 1:size(D, 1)
    D(k,:) = max(D(k,:), 0);  % 1)

    area_k = trapz(theta, D(k,:));
    if area_k > 0
        D(k,:) = D(k,:) ./ area_k; % 2)
    else
        warning('wsa_dir_Fourier:ZeroArea', ...
            'La distribucion en la fila %d tiene area cero tras el recorte.', k);
    end
end

%% Resultados

out = struct;
out.theta = theta;
out.D = D;

if use_second_order
    out.order = 2;
else
    out.order = 1;
end

end