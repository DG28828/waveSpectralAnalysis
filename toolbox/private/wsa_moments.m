function out_struct = wsa_moments(in_struct)
%wsa_moments - momentos espectrales de una función de densidad espectral de
%potencia
%
%   Esta calcula los momentos espectrales de un espectro de potencia, 
%   numeros de orden indicados.
%
%
%   Sintaxis:
%
%
%   Argumentos de entrada (requeridos):
%       in_struct - Entrada.
%                   Struct.
%               S: Vector de valores del espectro de potencia.
%               f: Vector de frecuencias.
%               n: vector con ordenes a calcular.
%
%                   
%
%
%   Argumentos de salida:
%   out_struct    - Estructura con:
%               m: valor de los momentos espectrales para los ordenes indicados
%


%% Manejo de entradas

arguments
    in_struct struct 
end

%% Verificaciones iniciales

if ~isfield(in_struct, 'S') || isempty(in_struct.S)
    error('El struct de entrada debe contener el campo S (arreglo con valores de espectro frecuencial)')
end

if ~isfield(in_struct, 'f') || isempty(in_struct.f)
    error('El struct de entrada debe contener el campo f (arreglo con valores de frecuencias del espectro frecuencial)')
end

if ~isfield(in_struct, 'n') || isempty(in_struct.n)
    error('El struct de entrada debe contener el campo n (ordenes a calcular)')
end

if numel(in_struct.S) ~= numel(in_struct.f)
    error('El vector de frecuencias f debe tener la misma cantidad de elementos que el vector S')
end

if any(diff(in_struct.f) <= 0)
    error('El vector de frecuencias f debe ser estrictamente creciente.')
end

if any(in_struct.n < 0) && any(in_struct.f == 0)
    error('No se pueden calcular momentos de orden negativo si f contiene 0.')
end

%Verificar que n sea numerico
if ~isnumeric(in_struct.n)
    error('El campo n debe ser un vector numérico con los órdenes de los momentos.')
end

%Verificar que S y f sean numericos reales
if ~isnumeric(in_struct.S) || ~isnumeric(in_struct.f)
    error('Los campos S y f deben ser numéricos.')
end

if any(isnan(in_struct.S)) || any(isnan(in_struct.f))
    error('Los campos S y f no deben contener NaN.')
end

%% Cálculo de momentos espectrales

S = in_struct.S(:);
f = in_struct.f(:);
orders = in_struct.n(:);

m = zeros(numel(orders), 1);
for k = 1:numel(orders)
    n = orders(k);
    m(k) = trapz(f, (f.^n).*S);
end

%% Salida
out_struct = struct();
out_struct.n = orders;
out_struct.m = m;

end




