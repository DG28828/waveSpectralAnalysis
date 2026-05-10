function out = wsa_velocity_transformation(beam, T, heading, pitch, roll)
%vel_preproc - Convierte velocidades orbitales desde coordenadas BEAM
%              hacia coordenadas XYZ del instrumento y coordenadas ENU.
%
%   Esta función transforma velocidades medidas en coordenadas de beams
%   de equipos Nortek hacia:
%
%       1. Coordenadas XYZ del instrumento
%       2. Coordenadas ENU, es decir Este-Norte-Arriba
%
%   Las coordenadas BEAM corresponden a las velocidades medidas a lo largo
%   de cada uno de los tres haces del instrumento.
%
%   Las coordenadas ENU corresponden a un sistema de referencia terrestre:
%       E: componente Este-Oeste
%       N: componente Norte-Sur
%       U: componente vertical, positiva hacia arriba
%
%   Sintaxis:
%       out = vel_preproc(beam, T, heading, pitch, roll)
%
%   Entradas:
%       beam    - Matriz de velocidades en coordenadas BEAM.
%                 Debe tener tamaño [3 x N], donde:
%                   fila 1 = beam 1
%                   fila 2 = beam 2
%                   fila 3 = beam 3
%                   columnas = muestras del burst
%
%       T       - Matriz de transformación de BEAM a XYZ.
%                 Debe tener tamaño [3 x 3].
%
%       heading - Rumbo del instrumento, en grados.
%
%       pitch   - Inclinación pitch del instrumento, en grados.
%
%       roll    - Inclinación roll del instrumento, en grados.
%
%   Salidas:
%       out     - Estructura con las matrices de transformación y las
%                 velocidades convertidas.
%
%                 out.xyz contiene las velocidades en coordenadas XYZ.
%                 out.enu contiene las velocidades en coordenadas ENU.
%
%   Nota:
%       La matriz de transformación debe recalcularse cada vez que cambien
%       heading, pitch o roll.
%
%       Si la matriz T proviene del archivo de encabezado ASCII de Nortek
%       con valores enteros grandes, puede ser necesario escalarla:
%
%           T = T/4096;
%
%       Esto depende de cómo haya sido exportada la matriz.

%% Verificaciones iniciales

if size(beam,1) ~= 3
    error('beam debe tener tamaño [3 x N], con cada fila representando un beam.');
end

if ~isequal(size(T), [3 3])
    error('T debe ser una matriz de transformación de tamaño [3 x 3].');
end

if ~isscalar(heading) || ~isscalar(pitch) || ~isscalar(roll)
    error('Se requiere heading, pitch y roll escalares.');
end



%% Conversión de Heading, Pitch y Roll
% Se resta 90 grados al heading para hacer que el eje X del instrumento
% sea comparable con el eje Este del sistema terrestre.
hdg = deg2rad(heading - 90);
pch = deg2rad(pitch);
rll = deg2rad(roll);

%% Matriz de rotación por heading
H = [ cos(hdg)  sin(hdg)  0;
     -sin(hdg)  cos(hdg)  0;
       0          0       1];

%% Matriz de inclinación combinada: pitch y roll
P = [ cos(pch), -sin(pch)*sin(rll), -cos(rll)*sin(pch);
      0,          cos(rll),          -sin(rll);
      sin(pch),  sin(rll)*cos(pch),  cos(pch)*cos(rll)];

%% Matriz de rotación total de XYZ a ENU
R = H*P;

%% Transformaciones

% BEAM -> XYZ
xyz = T * beam;

% XYZ -> ENU
enu = R * xyz;

%% Guardar resultados

out.input.beam = beam;
out.input.T = T;
out.input.heading = heading;
out.input.pitch = pitch;
out.input.roll = roll;

out.H = H;
out.P = P;
out.R = R;

out.xyz = xyz;
out.enu = enu;

end

