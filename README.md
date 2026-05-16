# Wave Spectral Analysis

Toolbox de MATLAB para analisis espectral y direccional de oleaje. Incluye
herramientas para estimar espectros de energia, calcular parametros
espectrales y direccionales, reconstruir espectros direccionales y procesar
datos crudos de instrumentos AWAC.

> Primera version en preparacion. El contenido puede cambiar levemente mientras se
> completan pruebas, ejemplos y documentacion.

## Caracteristicas

- Estimacion de espectros unilaterales de energia mediante el método de Welch-Bartlett (periodogramas medios con solapamiento).
- Correccion hidrodinamica para senales de presion usando el factor `Kp`.
- Calculo de parametros espectrales por espectro total y por bandas de
  frecuencia.
- Estimacion de coeficientes direccionales y espectros direccionales con
  serie de Fourier truncada y metodo MEM-I (Lygre & Krogstad).
- Calculo de parametros direccionales por bandas.
- Conversion de convencion cartesiana-hacia a convencion nautica-desde.
- Lectura, limpieza, escritura a NetCDF y preprocesamiento de datos AWAC.

## Funciones principales

| Funcion | Descripcion |
| --- | --- |
| `wsa_spectrum` | Estima espectros de energia para superficie libre o presion. |
| `wsa_spectral_parameters` | Calcula parametros espectrales totales y por bandas de frecuencia. |
| `wsa_dirspectrum` | Estima espectros direccionales con 2 métodos: Serie de Fourier Truncada (TFS) y MEM-I. |
| `wsa_directional_parameters` | Calcula parametros direccionales totales y por bandas de frecuencia. |
| `wsa_cartto2nautfrom` | Convierte direcciones a convencion nautica-desde. |
| `wsa_awac_read` | Lee datos crudos AWAC. |
| `wsa_awac_clean` | Limpia bursts AWAC segun control de calidad. |
| `wsa_awac_nc_write` | Escribe datos AWAC a formato NetCDF. |
| `wsa_awac_preprocess` | Preprocesa senales AWAC guardadas en formato NetCDF. |

Nota: Flujo de AWAC probado con AWAC 1Mhz de Primera Generación.

## Flujo AWAC

El toolbox incluye funciones para trabajar con datos crudos de AWAC:

```matlab
data = wsa_awac_read("...\datos_crudos\");
data_clean = wsa_awac_clean(data);
wsa_awac_nc_write(data_clean, "data_clean.nc");
info = wsa_awac_preprocess("data_clean.nc");
```

Funciones principales del flujo:

- `wsa_awac_read`: lee archivos desencriptados `.hdr`, `.whd` y `.wad`, construye un struct con los datos de la campaña y genera banderas de control de calidad de los estados de mar.
- `wsa_awac_clean`: en el modo automático elimina bursts marcados en la lectura o permite ingresar indices manualmente.
- `wsa_awac_nc_write`: exporta el struct generado por las funciones `wsa_awac_read` o `wsa_awac_clean` a un archivo en formato NetCDF.
- `wsa_awac_preprocess`: corrige señales AST, transforma velocidades orbitales a ejes geográficos ENU, filtra senales y agrega variables procesadas al NetCDF.

## Requisitos

- MATLAB. El toolbox se ha revisado con MATLAB R2024b.
- Signal Processing Toolbox para funciones como `hann`, `hamming`, `butter` y
  `filtfilt`.
- Funciones NetCDF de MATLAB para el flujo AWAC.

## Instalacion

Para usar el toolbox se debe clonar o descargar este repositorio y agregar la carpeta `toolbox` con todas sus
subcarpetas al path de MATLAB:

```matlab
addpath(genpath("...\repositorio\toolbox"))
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
- En `wsa_spectrum`, la senal se preprocesa removiendo media y tendencia antes
  de estimar el espectro.
- En el flujo direccional, la componente de frecuencia cero se excluye del
  analisis direccional.
- Las direcciones de `wsa_dirspectrum` y `wsa_directional_parameters` usan por
  defecto convencion cartesiana-hacia (angulos positivos medidos desde el eje X positivo en dirección contraria a las manecillas del reloj).
- Se asume que las velocidades orbitales X e Y de entrada corresponde a las coordenadas geográficas Este y Norte, respectivamente. Con valores positivos medidos hacia el Este y Norte.

## Licencia

Este proyecto se distribuye bajo la licencia incluida en `LICENSE`.
