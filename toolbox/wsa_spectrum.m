function [S, f] = wsa_spectrum(eta, fs, varargin)
%wsa_spectrum - espectro de energía.
%
%   Esta función estima el espectro de energía de un registro de mediciones 
%   de superficie libre (eta). El espectro calculado corresponde a la
%   densidad espectral de potencia unilateral (frecuencias positiavs) del 
%   registro medido. El espectro se calcula mediante el método de
%   preiodogramas medio, siguiendo la metodología de Welch-Barlett
%
%   Sintaxis:
%
%
%   Argumentos de entrada:
%       eta - secuencia de superficie libre 
%           vector
%       fs - frecuencia de muestreo (Hz)
%           entero
%       DoF - grados de libertad (Degrees of Freedom) del espectro. Debe
%       ser entero, par, mayor a 2.
%           entero | (opcional) Por defecto: DoF = 16
%       pc - Bandera para imprimir en consola (print consle): brinda
%       información acerca de modificaciones en valores de M, N, N0, K, Nfft
%           bool | (opcional) Por defecto: 0
%
%   Argumentos de salida:
%       S - estimador del espectro de energía unilateral [unidad de eta]^2/Hz
%           vector
%       f - frecuencias físicas Hz
%           vector
%
% -------------------------------------------------------------------------
% Universidad de Costa Rica
% Escuela de Ingeniería Civil
% Autor: Danny Garro Arias
% Fecha de creación: 30/01/2026
% Fecha de modificación: 30/01/2026
% -------------------------------------------------------------------------

%% Manejo de entradas

%Valores por defecto
DoF_default = 16;
pc_default = 0;

%Input parser
p = inputParser;

addRequired(p, 'eta');
addRequired(p, 'fs');

addParameter(p, 'DoF', DoF_default);
addParameter(p, 'pc',    pc_default);

parse(p, eta, fs, varargin{:});

%Resultados
DoF    = p.Results.DoF;
pc     = p.Results.pc;

%% Verificaciones iniciales

%Verificar eta es vector columna
if size(eta, 1) ~= length(eta)
    eta = eta';
end

if DoF ~= DoF_default
    if DoF <= 2 || mod(DoF, 1) ~= 0 || mod(DoF, 2) ~= 0
        error('DoF debe ser entero, par, mayor a 2')
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
Nfft = 2^nextpow2(4*length(eta));
[I, W] = wsa_psdwb(eta, ventana, 'K', K, 'Nfft', Nfft, 'pc', pc);

%Convertir psd bilateral a espectro unilateral y convertir 
% unidades de [unidad de eta]^2/rad/muestra a [unidad de eta]^2/rad/s *
S = 2*I(W>=0)/fs;           
f = fs*W(W>=0)/(2*pi);

% *Esta conversión es la siguiente:
%       W:  frecuencia angular digital [rad/muestra]
%       fs: frecuencia de muestreo [muestra/s]
%       f:  frecuencia física [rad/s] = [rad/muestra]/[s/muestra]


end