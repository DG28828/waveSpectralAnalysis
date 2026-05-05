function out = wsa_highpass_filter(x, fs, fc, order, pad_seconds)
%wsa_highpass_filter - Filtro pasa-altas de fase cero con padding por reflexión
%
% INPUT:
%   x           : vector o matriz [muestras x estados]
%   fs          : frecuencia de muestreo [Hz]
%   fc          : frecuencia de corte [Hz]
%   order       : orden del filtro
%   pad_seconds : duración del padding en segundos
%
% OUTPUT:
%   out.x_filt : señal filtrada
%   out.b      : coeficientes numerador
%   out.a      : coeficientes denominador
%   out.fc     : frecuencia de corte
%   out.fs     : frecuencia de muestreo

if nargin < 4 || isempty(order)
    order = 2;
end

if nargin < 5 || isempty(pad_seconds)
    pad_seconds = 300; % medio periodo de corte si fc = 1/600
end

x = squeeze(x);

if isvector(x)
    x = x(:);
end

[N, nSignals] = size(x);

if fc <= 0
    error('La frecuencia de corte debe ser mayor que cero.');
end

if fc >= fs/2
    error('La frecuencia de corte debe ser menor que la frecuencia de Nyquist.');
end

T = N/fs;

if T <= 3/fc
    warning(['La duración del registro es %.2f s y el periodo de corte es %.2f s. ' ...
             'El filtrado puede no ser completamente confiable para esta frecuencia de corte.'], ...
             T, 1/fc);
end

Wn = fc/(fs/2);
[b, a] = butter(order, Wn, 'high');

x_filt = nan(size(x));

nPad = round(pad_seconds*fs);
nPad = min(nPad, N-1);

for j = 1:nSignals

    y = x(:,j);

    if all(isnan(y))
        x_filt(:,j) = y;
        continue
    end

    % Rellenar NaN antes de filtrar
    idx_nan = isnan(y);

    if any(idx_nan)
        t = (0:N-1)'/fs;

        if all(idx_nan)
            x_filt(:,j) = y;
            continue
        end

        y(idx_nan) = interp1( ...
            t(~idx_nan), ...
            y(~idx_nan), ...
            t(idx_nan), ...
            'linear', ...
            'extrap');
    end

    % Remover tendencia lineal antes del filtro
    y = detrend(y);

    % Padding por reflexión
    if nPad > 0
        y_left  = flipud(y(2:nPad+1));
        y_right = flipud(y(end-nPad:end-1));

        y_pad = [y_left; y; y_right];

        y_pad_filt = filtfilt(b, a, y_pad);

        x_filt(:,j) = y_pad_filt(nPad+1:nPad+N);
    else
        x_filt(:,j) = filtfilt(b, a, y);
    end
end

out.x_filt = x_filt;
out.b = b;
out.a = a;
out.fc = fc;
out.fs = fs;
out.order = order;
out.pad_seconds = pad_seconds;
out.nPad = nPad;

end