# Wave Spectral Analysis 
[![View Wave Spectral Analysis on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/183891-wave-spectral-analysis)     [![es](https://img.shields.io/badge/lang-es-yellow.svg)](https://github.com/DG28828/waveSpectralAnalysis/blob/main/README.es.md)

MATLAB toolbox for wave spectral and directional analysis. It includes
tools to estimate energy spectra, compute spectral and directional
parameters, reconstruct directional spectra, and process raw AWAC
instrument data.

## Features

- Estimation of one-sided energy spectra using the Welch-Bartlett method
  (averaged periodograms with overlap).
- Hydrodynamic correction for pressure signals using the `Kp` factor.
- Computation of spectral parameters for the total spectrum and frequency
  bands.
- Estimation of directional coefficients and directional spectra using a
  truncated Fourier series and the MEM-I method (Lygre & Krogstad).
- Computation of directional parameters by frequency bands.
- Conversion from Cartesian-to convention to nautical-from convention.
- Reading, cleaning, NetCDF writing, and preprocessing of AWAC data.

## Main functions

| Function | Description |
| --- | --- |
| `wsa_spectrum` | Estimates energy spectra for free-surface elevation or pressure. |
| `wsa_spectral_parameters` | Computes total spectral parameters and parameters by frequency bands. |
| `wsa_dirspectrum` | Estimates directional spectra using 2 methods: Truncated Fourier Series (TFS) and MEM-I. |
| `wsa_directional_parameters` | Computes total directional parameters and parameters by frequency bands. |
| `wsa_cartto2nautfrom` | Converts directions to the nautical-from convention. |
| `wsa_awac_read` | Reads raw AWAC data. |
| `wsa_awac_clean` | Cleans AWAC bursts based on quality control. |
| `wsa_awac_nc_write` | Writes AWAC data to NetCDF format. |
| `wsa_awac_preprocess` | Preprocesses AWAC signals stored in NetCDF format. |

Note: The AWAC workflow has been tested with a first-generation 1 MHz AWAC.

## Usage Examples

Detailed usage examples are available as .mlx Live Scripts in the \toolbox\examples folder. A summary of the examples is provided below.

### Input Data
Sample data for the example is included in the \toolbox\example_data folder.
```matlab
data = load('..\example_data\burst_data.mat');
AST = data.burst_data.processed.ast(:, 1);                    %Free-surface elevation
U = data.burst_data.processed.velocity_enu(:, 1);             %Orbital velocity in X.
V = data.burst_data.processed.velocity_enu(:, 2);             %Orbital velocity in Y.

fs = data.burst_data.general.fs;                              %Sampling frequency
ast_mean = data.burst_data.general.ast_mean;                  %Mean level measured from the top of the instrument
cell_position = data.burst_data.general.cell_position;        %Distance from the top of the instrument to the orbital velocity measurement cell.
mounting_height = data.burst_data.general.mounting_height;    %Equipment mounting height.

h   = ast_mean + mounting_height;                             %Seafloor depth.                                            
z_v = cell_position - ast_mean;                               %Measurement depth for orbital velocities.
```
<p align="center">
  <img src="images/input_data.png" alt="Input Data example" width="850">
</p>


### Energy Spectra
```matlab
[out_Spec, info_Spec] = wsa_spectrum(AST, fs, 'DoF', 64);
f = out_Spec.f;
S = out_Spec.S;
```
<p align="center">
  <img src="images/spectra.png" alt="Wave Spectra example" width="500">
</p>

### Spectral Parameters

```matlab
out_Spec_Params = wsa_spectral_parameters(out_Spec)
```
<p align="center">
  <img src="images/spectral_parameters.png" alt="Spectral Parameters example" width="300">
</p>

### Directional Spectra
```matlab
[out_DirSpec, info_DirSpec] = wsa_dirspectrum(AST, U, V, fs, 'SUV', ...
                                             'z_v', z_v, ...
                                             'h', h);
f = out_DirSpec.MEM.f;
theta = out_DirSpec.MEM.theta;
E = out_DirSpec.MEM.E;
```
<p align="center">
  <img src="images/directional_spectra.png" alt="Directional Wave Spectra example" width="500">
</p>

### Directional Parameters
```matlab
out_Dir_Params = wsa_directional_parameters(out_DirSpec.MEM)
```
<p align="center">
  <img src="images/directional_parameters.png" alt="Directional Parameters example" width="300">
</p>

## AWAC

The toolbox includes functions for working with raw AWAC data:

```matlab
data = wsa_awac_read("...\raw_data\");
data_clean = wsa_awac_clean(data);
wsa_awac_nc_write(data_clean, "data_clean.nc");
info = wsa_awac_preprocess("data_clean.nc");
```

Main functions:

- `wsa_awac_read`: reads decrypted `.hdr`, `.whd`, and `.wad` files, builds a struct with the campaign data, and generates quality-control flags for sea states.
- `wsa_awac_clean`: in automatic mode, removes bursts flagged during reading or allows manual indices to be provided.
- `wsa_awac_nc_write`: exports the struct generated by `wsa_awac_read` or `wsa_awac_clean` to a NetCDF file.
- `wsa_awac_preprocess`: corrects AST signals, transforms orbital velocities to geographic ENU axes, filters signals, and adds processed variables to the NetCDF file.

## Requirements

- MATLAB. The toolbox has been tested with MATLAB R2024b.
- Signal Processing Toolbox.
- MATLAB NetCDF functions for the AWAC workflow.

## Installation

Three installation options are shown below. Options 1 or 2 are recommended,
because the `.mltbx` toolbox file automatically resolves the function paths.

### 1) From MATLAB File Exchange

In MATLAB, go to the Home tab and open Get Add-Ons. Search for the toolbox as
Wave Spectral Analysis and install it, or download the `.mltbx` toolbox file.
Using this method downloads the latest release published on GitHub.

### 2) From the GitHub release

Download the release of interest, then run the `.mltbx` toolbox file or use the
source code. In the second case, the functions must be added to the path as
described in option 3.

### 3) Downloading the source code

Clone or download the repository and add the `toolbox` folder, including all its
subfolders, to the MATLAB path:

```matlab
addpath(genpath("...\waveSpectralAnalysis\toolbox"))
```

To verify that the path was correctly configured:

```matlab
which wsa_spectrum
which wsa_psdwb
```

Both commands should return paths inside the `toolbox` folder.

## Conventions and notes

- Frequencies are expressed in Hz.
- Sensor depths below the mean water level are indicated with a negative sign,
  for example `z_p = -0.5`.
- In `wsa_spectrum`, the signal is preprocessed by removing the mean and trend
  before estimating the spectrum.
- In the directional analysis, the zero-frequency component is excluded from the
  directional analysis.
- The directions from `wsa_dirspectrum` and `wsa_directional_parameters` use the
  Cartesian-to convention by default: positive angles are measured from the
  positive X-axis in the counterclockwise direction.
- It is assumed that the input X and Y orbital velocities correspond to the
  geographic East and North coordinates, respectively, with positive values
  measured toward the East and North.

## License

This project is distributed under the license included in `LICENSE`.
