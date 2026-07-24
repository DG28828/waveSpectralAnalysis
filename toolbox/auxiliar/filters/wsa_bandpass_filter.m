function xf = wsa_bandpass_filter(x, fs , f_i, f_f)

%% Manejo de entardas

arguments
    x {mustBeNumeric, mustBeVector}
    fs  (1,1) double {mustBeFinite, mustBePositive}
    f_i (1,1) double {mustBeFinite, mustBeNonnegative}
    f_f (1,1) double {mustBeFinite, mustBePositive}
end

%% Verificaciones iniciales


if isempty(x)
    error('La señal de entrada a filtro no puede estar vacía.');
end

if any(~isfinite(x(:)))
    error('La señal de entrada al filtro contiene valores NaN o Inf.');
end

if f_i >= f_f
    error('La frecuencia de corte inferior f_i debe ser menor que la frecuencia de corte superior f_f.');
end

f_nyquist = fs/2;

if f_f >= f_nyquist
    error('La frecuencia de corte superior f_f debe ser menor que la frecuencia de Nyquist fs/2 = %.6g Hz.', f_nyquist);
end

%% Preparación de la señal

input_is_row_flag = isrow(x);

x = double(x(:));
N = numel(x);

% if N < 5
%     error('La señal debe contener al menos cinco muestras.');
% end

%% Determinar la longitud del filtro

bandwidth = f_f - f_i;

% Resolución frecuencial aproximada del registro.
df = fs/N;

% Transición equivalente al 10 % del ancho de la banda de paso.
transition_width = 0.10*bandwidth;

% Evitar que la transición superior exceda Nyquist.
transition_width = min(transition_width, f_nyquist - f_f);

% Limitar también la transición inferior.
if f_i > 0
    transition_width = min(transition_width, f_i/2);
end

% No se puede diseñar una transición mucho menor que la resolución
% frecuencial disponible en el registro.
if transition_width < df
    warning('La transición requerida es menor que la resolución frecuencial del registro. Se utilizará df = %.6g Hz.', df);
    transition_width = df;
end

% Aproximación para una ventana Hann:
%
%     orden ≈ 3.1*fs/ancho_de_transición
%
filter_order_required = ceil(3.1*fs/transition_width);

% Se requiere un orden par para obtener una longitud impar y una respuesta impulsional simétrica con una muestra central.
if mod(filter_order_required, 2) ~= 0
    filter_order_required = filter_order_required + 1;
end

filter_length_required = filter_order_required + 1;

% Limitar la longitud según el número de muestras disponible.
max_filter_length = 2*N - 1;

filter_length = min(filter_length_required, max_filter_length);

% Garantizar que la longitud sea impar.
if mod(filter_length, 2) == 0
    filter_length = filter_length - 1;
end

if filter_length < filter_length_required
    warning('La señal es demasiado corta para obtener completamente la transición estimada. La longitud del filtro se limitó a %d coeficientes.', filter_length);
end

half_length = (filter_length - 1)/2;

%% Construir la respuesta al impulso

n = (-half_length:half_length).';

%% Filtro

% Filtro pasa bajas con frecuencia de corte superior
h_upper = (2*f_f/fs).*sinc(2*f_f*n/fs);

if f_i == 0
    % Caso pasa-bajos.
    h_ideal = h_upper;

else
    % Filtro pasa-bajos ideal con frecuencia de corte inferior.
    h_lower = (2*f_i/fs).*sinc(2*f_i*n/fs);

    % Filtro pasabanda como la diferencia de ambos filtros.
    h_ideal = h_upper - h_lower;
end

%% Aplicar ventaan Hann al filtro

window = hann(filter_length, 'symmetric');

h = h_ideal.*window;

%% Normalizar la ganancia

if f_i == 0
    % Ganancia unitaria en frecuencia cero para el pasa-bajos.
    dc_gain = sum(h);

    if abs(dc_gain) < eps
        error('No fue posible normalizar el filtro pasa-bajos.');
    end

    h = h/dc_gain;

else
    % Normalizar la ganancia en el centro de la banda de paso.
    center_frequency = (f_i + f_f)/2;

    center_response = sum(h.*exp(-1i*2*pi*center_frequency*n/fs));

    center_gain = abs(center_response);

    if center_gain < eps
        error('No fue posible normalizar el filtro pasabanda.');
    end

    h = h/center_gain;
end


%% Extender la señal mediante reflexión

if half_length > 0
    left_padding = flipud(x(2:half_length + 1));
    right_padding = flipud(x(end - half_length:end - 1));

    x_padded = [left_padding; x; right_padding];

else
    x_padded = x;
end

%% Aplicar el filtro

% Al emplear una respuesta impulsional simétrica y una convolución
% centrada no se introduce un desplazamiento temporal neto.
xf_padded = conv(x_padded, h, 'same');

% Recuperar el tramo correspondiente a la señal original.
first_index = half_length + 1;
last_index  = half_length + N;

xf = xf_padded(first_index:last_index);

%% Recuperar la orientación original

if input_is_row_flag
    xf = xf.';
end


end