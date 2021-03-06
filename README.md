# SPIRES

Snow Property Inversion from Remote Sensing (SPIReS)

2001-2019 Sierra data at (ftp:// links don't work because of [GitHub markdown bug](https://github.com/eedeebee/github-markdown-ftp-bug)): ftp://ftp.snow.ucsb.edu/pub/org/snow/products/SPIRES/Sierra/

Example to run one year over the Sierra Nevada USA region. Requires MATLAB + Parallel Computing Toolbox

1. Download example data (103GB),
ftp://ftp.snow.ucsb.edu/pub/org/snow/products/SPIRES/Sierra/ExampleData

2. Checkout the code, https://github.com/edwardbair/SPIRES.git

3. Start a MATLAB session

4. Add the code directory and all its subdirectories to your MATLAB path,

"addpath(genpath([location where you checked out the code to]))"

5. Load the example inputs, i.e. "load Sierra_example_inputs.mat" 

6. Examine the comments at the top of the two files called "fill_and_run_modis.m" &
"smoothSPIREScube.m" to understand the inputs used, e.g. "edit fill_and_run_modis"

7. Insert the full paths, i.e. where you downloaded the example data to, in front of the following variables:
Ffile
hdfbasedir
topofile

For example, if you downloaded to "/raid/spires", then

Ffile='/raid/spires/lut_modis_b1to7_3um_dust.mat'; 
hdfbasedir='/raid/spires/mod09ga';
topofile='/raid/spires/topo/SierraElevation.h5';

8. Call "run_modis_Sierra_example.m"

Notes:

SPIRES takes one or more MODIS tiles and then, if needed, 
mosaics and reprojects/crops them to match the elevation dataset (and its map information) in the topography file. 
In this case, h08v04, h09v04, and h08v05 are mosaiced and cropped to the Sierra Nevada domain.

Running the full year will take a long time and a lot of RAM, depending on the number of cores used. Using 60 AMD EPYC cores, plan on about 6 hours and about 400GB RAM, or about 7 GB RAM/core. For testing, you can run with a single core.

The minimum amount of time that'll work for smoothSPIREScube is 1 calendar month, i.e dom 1 through 28 to 31, but the smoothing works best over a few months. You can increase "tolval" to speed up computations and decrease quality. You're smart, you'll figure it out.

Reference:

Bair, E.H, Stillinger, T., and Dozier J (in press), Snow Property Inversion from Remote Sensing (SPIReS): A Generalized Multispectral Unmixing Approach with Examples from MODIS and Landsat 8 OLI, IEEE TGRS, doi: 10.1109/TGRS.2020.3040328 (https://dx.doi.org/10.1109/TGRS.2020.3040328)

NB 2020-10-27
