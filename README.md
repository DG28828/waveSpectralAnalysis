# Wave Spectral Analysis [![View Wave Spectral Analysis on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/183891-wave-spectral-analysis)


Toolbox de MATLAB para análisis espectral y direccional de oleaje. Incluye
herramientas para estimar espectros de energía, calcular parámetros
espectrales y direccionales, reconstruir espectros direccionales y procesar
datos crudos de instrumentos AWAC.

## Características

- Estimación de espectros unilaterales de energia mediante el método de Welch-Bartlett (periodogramas medios con solapamiento).
- Corrección hidrodinámica para señales de presión usando el factor `Kp`.
- Cálculo de parámetros espectrales por espectro total y por bandas de
  frecuencia.
- Estimación de coeficientes direccionales y espectros direccionales con
  serie de Fourier truncada y método MEM-I (Lygre & Krogstad).
- Cálculo de parámetros direccionales por bandas.
- Conversión de convención cartesiana-hacia a convencion náutica-desde.
- Lectura, limpieza, escritura a NetCDF y preprocesamiento de datos AWAC.

## Funciones principales

| Función | Descripción |
| --- | --- |
| `wsa_spectrum` | Estima espectros de energía para superficie libre o presión. |
| `wsa_spectral_parameters` | Calcula parámetros espectrales totales y por bandas de frecuencia. |
| `wsa_dirspectrum` | Estima espectros direccionales con 2 métodos: Serie de Fourier Truncada (TFS) y MEM-I. |
| `wsa_directional_parameters` | Calcula parámetros direccionales totales y por bandas de frecuencia. |
| `wsa_cartto2nautfrom` | Convierte direcciones a convencion náutica-desde. |
| `wsa_awac_read` | Lee datos crudos AWAC. |
| `wsa_awac_clean` | Limpia bursts AWAC según control de calidad. |
| `wsa_awac_nc_write` | Escribe datos AWAC a formato NetCDF. |
| `wsa_awac_preprocess` | Preprocesa señales AWAC guardadas en formato NetCDF. |

Nota: Funciones de AWAC probadas con AWAC 1Mhz de Primera Generación.

## AWAC

El toolbox incluye funciones para trabajar con datos crudos de AWAC:

```matlab
data = wsa_awac_read("...\datos_crudos\");
data_clean = wsa_awac_clean(data);
wsa_awac_nc_write(data_clean, "data_clean.nc");
info = wsa_awac_preprocess("data_clean.nc");
```

Funciones principales:

- `wsa_awac_read`: lee archivos desencriptados `.hdr`, `.whd` y `.wad`, construye un struct con los datos de la campaña y genera banderas de control de calidad de los estados de mar.
- `wsa_awac_clean`: en el modo automático elimina bursts marcados en la lectura o permite ingresar indices manualmente.
- `wsa_awac_nc_write`: exporta el struct generado por las funciones `wsa_awac_read` o `wsa_awac_clean` a un archivo en formato NetCDF.
- `wsa_awac_preprocess`: corrige señales AST, transforma velocidades orbitales a ejes geográficos ENU, filtra señales y agrega variables procesadas al NetCDF.

## Requisitos

- MATLAB. El toolbox se ha revisado con MATLAB R2024b.
- Signal Processing Toolbox.
- Funciones NetCDF de MATLAB para el flujo AWAC.

## Instalación
Se muestran tres opciones para instalación del toolbox. Se recomienda utilizar la 1 o 2, debido a  que el archivo de tolbox .mltbx resuelve los paths de las funciones de forma automática.

### 1) Desde Matlab File Exchange
En Matlab, ir a la pestaña Home, y abrir Get Add-Ons. Buscar el toolbox como Wave Spectral Analysis e instalar o descargar el archivo de toolbox .mltbx. Al usar este método se descarga el último release publicado en GitHub.

### 2) Desde el release de Github
Descargar el release de interés, luego ejecutar el archivo de toolbox .mltbx o usar el código fuente. En el segundo caso, se deben agregar las funciones al path como se detalla en la opción 3.

### 3) Descargando el código fuente

Clonar o descargar el repositorio y agregar la carpeta `toolbox` con todas sus
subcarpetas al path de MATLAB:

```matlab
addpath(genpath("...\waveSpectralAnalysis\toolbox"))
```

Para verificar que el path quedo correctamente configurado:

```matlab
which wsa_spectrum
which wsa_psdwb
```

Ambos comandos deben devolver rutas dentro de la carpeta `toolbox`.


## Convenciones y notas

- Las frecuencias se expresan en Hz.
- Las profundidades de sensores bajo el nivel medio se indican con signo
  negativo, por ejemplo `z_p = -0.5`.
- En `wsa_spectrum`, la señal se preprocesa removiendo media y tendencia antes
  de estimar el espectro.
- En el análisis direccional, la componente de frecuencia cero se excluye del
  análisis direccional.
- Las direcciones de `wsa_dirspectrum` y `wsa_directional_parameters` usan por
  defecto convencion cartesiana-hacia (angulos positivos medidos desde el eje X positivo en dirección contraria a las manecillas del reloj).
- Se asume que las velocidades orbitales X e Y de entrada corresponde a las coordenadas geográficas Este y Norte, respectivamente. Con valores positivos medidos hacia el Este y Norte.

## Licencia

Este proyecto se distribuye bajo la licencia incluida en `LICENSE`.


