function [out, info] = wsa_spectrum(X, fs, varargin)
%wsa_spectrum - espectro de energía.
%
%   Esta función estima el espectro de energía de una secuencia de 
%   datos (X). El espectro calculado corresponde a la densidad espectral 
%   de potencia unilateral (frecuencias positivas). El espectro se calcula 
%   mediante el método de periodogramas medio, siguiendo la metodología de 
%   Welch-Barlett.
%
%
%   Sintaxis:
%       out = wsa_spectrum(X, fs) estima el espectro de energía unilateral
%           de la señal X, muestreada a una frecuencia fs (Hz).
%
%       [out, info] = wsa_spectrum(X, fs) devuelve adicionalmente una 
%           estructura info con los parámetros finales utilizados en el cálculo
%           y métricas de validación energética.
%
%
%   Argumentos de entrada (requeridos):
%       X       - Señal de entrada.
%                   Vector columna o fila.
%
%       fs      - Frecuencia de muestreo.
%                   Escalar positivo (Hz).
%
%
%   Parámetros Nombre-Valor (opcionales):
%       'DoF'   - Grados de libertad (Degrees of Freedom) del espectro.
%                   Entero par, mayor o igual a 2.
%                   Por defecto: DoF = 16.
%                   Se cumple que DoF = 2K.
%
%       'pc'    - Print console. Muestra en consola información de
%                   validación energética.
%                   true | false
%                   Por defecto: false
%
%
%   Argumentos de salida:
%   out         - Estructura con:
%       S           - Estimador del espectro de energía unilateral
%                   [unidad de X]^2 / Hz
%       f           - Frecuencias físicas (Hz)
%
%   info        - Estructura con los parámetros y métricas finales:
%                   M, N, N0, K, Nfft, DoF, window,
%                   fs, varianza, m0, error_relativo
%
%
%   Notas:
%   • El espectro se obtiene a partir de la PSD bilateral estimada
%     mediante WSA_PSDWB, empleando ventana Hann y un traslape del 50 %%.
%   • La conversión de PSD bilateral [X^2 / rad/muestra] a espectro
%     unilateral [X^2 / Hz] se realiza considerando:
%
%         f = fs·W / (2π)
%
%     y duplicando todas las componentes excepto la frecuencia cero.
%   • Se realiza una validación energética verificando que:
%
%         ∫_0^∞ S(f) df ≈ var(X)
%
%     reportando el error relativo porcentual.
%
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 30/01/2026
% Fecha de modificación: 20/02/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
DoF_default = 16;
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'X');
addRequired(p, 'fs');

addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, X, fs, varargin{:});

%Resultados
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%% Verificaciones iniciales

%Verificar eta es vector columna
if size(X, 1) ~= length(X)
    X = X';
end

if DoF ~= DoF_default
    if DoF < 2 || mod(DoF, 1) ~= 0 || mod(DoF, 2) ~= 0
        error('DoF debe ser entero, par, mayor o igual a 2')
    end
end

%% Calculo del espectro de energía
% Se calcula el espectro de energía unilateral a partir de la estimación de
% densidad de potencia mediante el método de Welch-Barlett. Los parámetros
% empleados son:
%   ventana: Von Hann
%   K: tal que cumpla con los DoF. Por defecto K = 8 (Recordar DoF = 2K)
%   N: Por defecto N = 2*M/(K+1) para N0 = N/2
%   N0: Por defecto N0 = N/2, para un porcentaje de traslape del 50 % que
%       disminuye la varainza a aproximadamente la mitad (mas traslape no dismiuye mas la varianza).
%   Nfft: la potencia de 2 mayor mas cercana a 4 veces N.

ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(X)/(K+1)));
[out_pswb, info] = wsa_psdwb(X, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);
I = out_pswb.I;
W = out_pswb.W;
%Convertir psd bilateral a espectro unilateral y convertir 
% Conversión:
%   PSD bilateral: [X^2 / rad/muestra]
%   PSD unilateral: [X^2 / rad/s] = [eta^2 / Hz]
S = I(W>=0)/fs;   
S(2:end) = 2*S(2:end); %La componente DC (W=0) no se duplica
f = fs*W(W>=0)/(2*pi);

% *Esta conversión es la siguiente:
%       W:  frecuencia angular digital [rad/muestra]
%       fs: frecuencia de muestreo [muestra/s]
%       f:  frecuencia física [rad/s] = [rad/muestra]/[s/muestra]

%Validación energética:
%   Se verifica el cumplimiento de integral_0_inf(S(f)df) = varianza
m0 = trapz(f, S);       %El momento de primer orden es el área bajo la curva
varianza = var(X);     %Varianza de la señal de entrada
error_relativo = 100*abs(m0-varianza)/varianza;
if pc
    fprintf('Validación energética:\n\t m0 = %.4f (área bajo la curva) \n\t varianza señal = %.4f \n\t error relativo = %.2f %%\n', m0, varianza, error_relativo)
end

%Struct para resultados
out = struct;
out.S = S;
out.f = f;

%Agregar información adicional al struct de info
info.fs = fs;
info.varianza = varianza;  
info.m0 = m0;
info.error_relativo = error_relativo;

end