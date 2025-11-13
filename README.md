# Greece Climate Map - Installation & Usage Guide

## Prerequisites

This script requires R to be installed on your system. If R is not installed, please follow these steps:

### Installing R

1. **Download R:**
   - Visit https://cran.r-project.org/bin/windows/base/
   - Download the latest version of R for Windows
   - Run the installer and follow the installation wizard

2. **Install RStudio (Optional but Recommended):**
   - Visit https://posit.co/download/rstudio-desktop/
   - Download and install RStudio Desktop
   - RStudio provides a better interface for running R scripts

### Installing Required R Packages

Once R is installed, you can either:

**Option A: Run the script directly** - The script will install packages automatically on first run (this may take some time)

**Option B: Install packages manually** - Open R or RStudio and run:
```r
install.packages("remotes")
remotes::install_github("inSileco/rchelsa")
remotes::install_github("chris-prener/biscale")
install.packages(c("geodata", "tidyverse", "sf", "terra", "biscale", "elevatr", "cowplot", "gridGraphics", "rayshader"))
```

## Running the Script

### Method 1: Using RStudio (Recommended)
1. Open RStudio
2. Open `greece_climate_map.R`
3. Click "Source" button or press Ctrl+Shift+S to run the entire script

### Method 2: Using R Command Line
1. Open R (or RStudio)
2. Navigate to the script directory:
   ```r
   setwd("C:/12_CODINGHARD/greece_climate")
   ```
3. Run the script:
   ```r
   source("greece_climate_map.R")
   ```

### Method 3: Using Rscript (if R is in PATH)
```powershell
Rscript greece_climate_map.R
```

## Output Files

The script will generate:
- `greece_bivariate_2d.png` - 2D bivariate map
- `greece-bivariate-3d.png` - 3D rendered map
- `CHELSA_bio10_01.tif` - Temperature data
- `CHELSA_bio10_12.tif` - Precipitation data
- `brown_photostudio_02_4k.hdr` - HDRI lighting file
- Various temporary files from geodata downloads

## Notes

- The script will download climate data (~100-200 MB) on first run
- The 3D rendering process may take several minutes
- Ensure you have a stable internet connection for data downloads

