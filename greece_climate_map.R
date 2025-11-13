# 1. PACKAGES
#------------------

# Set up user library if system library is not writable
if (!dir.exists(Sys.getenv("R_LIBS_USER"))) {
    dir.create(Sys.getenv("R_LIBS_USER"), recursive = TRUE)
}
.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths()))

# Function to check and install packages
check_and_install <- function(pkg, github = FALSE, repo = NULL) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        if (github) {
            if (!require("remotes", quietly = TRUE)) {
                install.packages("remotes", repos = "https://cran.rstudio.com/")
            }
            remotes::install_github(repo)
        } else {
            install.packages(pkg, repos = "https://cran.rstudio.com/")
        }
        library(pkg, character.only = TRUE)
    }
}

# Install remotes if needed
if (!require("remotes", quietly = TRUE)) {
    install.packages("remotes", repos = "https://cran.rstudio.com/")
}

# Install GitHub packages if needed
if (!require("rchelsa", quietly = TRUE)) {
    remotes::install_github("inSileco/rchelsa")
}

if (!require("biscale", quietly = TRUE)) {
    remotes::install_github("chris-prener/biscale")
}

# Install and load all packages
if (!require("pacman", quietly = TRUE)) {
    install.packages("pacman", repos = "https://cran.rstudio.com/")
}

pacman::p_load(
    geodata, tidyverse, sf, terra,
    rchelsa, biscale, elevatr, cowplot,
    gridGraphics, rayshader
)

# 2. CHELSA DATA
#----------------

# set the working directory
main_dir <- getwd()

# define a vector of IDs to download
ids <- c(1, 12)

# function to download CHELSA data
download_chelsa_data <- function(id, path){
    rchelsa::get_chelsea_data(
        categ = "clim", type = "bio",
        id = id, path = path
    )
}

# download data for each id
lapply(ids, download_chelsa_data, path = main_dir)

list.files()

# load the raster files
temp <- terra::rast("CHELSA_bio10_01.tif")
prec <- terra::rast("CHELSA_bio10_12.tif")

# average precipitation
prec_average <- prec / 30

# Combine average temperature and precipitation
# into a raster stack
temp_prec <- c(temp, prec_average)

# assign names to each layer in the stack
names(temp_prec) <- c("temperature", "precipitation")

# 3. COUNTRY POLYGON
#-------------------

country_sf <- geodata::gadm(
    country = "GRC", level = 0,
    path = main_dir
) |>
sf::st_as_sf()

# 4. CROP AND RESAMPLE
#---------------------

# define the target CRS
target_crs <- "EPSG:3035"

# Project country to target CRS and get bounding box for framing
country_sf_projected <- sf::st_transform(country_sf, crs = target_crs)
greece_bbox <- sf::st_bbox(country_sf_projected)

# crop the input raster to the
# country's extent and apply a mask
temp_prec_country <- terra::crop(
    temp_prec, country_sf,
    mask = TRUE
)

# Note: TIFF saving commented out due to disk space constraints
# Uncomment below to save cropped raster as TIFF:
# terra::writeRaster(
#     temp_prec_country,
#     filename = "greece_temp_prec_cropped.tif",
#     overwrite = TRUE
# )

# Obtain AWS tiles DEM data from elevatr
# convert to terra SpatRaster and crop
dem <- elevatr::get_elev_raster(
    locations = country_sf, z = 8,
    clip = "locations"
) |> terra::rast() |>
terra::crop(country_sf, mask = TRUE)

# resample the raster to match DEM resolution
# using bilinear interpolation, then reproject

temp_prec_resampled <- terra::resample(
    x = temp_prec_country,
    y = dem, method = "bilinear"
) |> terra::project(target_crs)

# Project DEM to target CRS and resample to match climate data exactly
dem_projected <- terra::project(dem, target_crs)
dem_resampled <- terra::resample(
    x = dem_projected,
    y = temp_prec_resampled,
    method = "bilinear"
)

# Note: TIFF saving commented out due to disk space constraints
# Uncomment below to save processed rasters as TIFF files:
# terra::writeRaster(
#     temp_prec_resampled,
#     filename = "greece_temp_prec_processed.tif",
#     overwrite = TRUE,
#     filetype = "GTiff"
# )
# terra::writeRaster(
#     dem_resampled,
#     filename = "greece_dem_processed.tif",
#     overwrite = TRUE,
#     filetype = "GTiff"
# )

# plot the resampled raster
terra::plot(temp_prec_resampled)

# convert the raster to dataframe with coordinates
temp_prec_df <- as.data.frame(
    temp_prec_resampled, xy = TRUE
)

# Get exact extent from the data for consistent mapping
data_xlim <- c(min(temp_prec_df$x, na.rm = TRUE), max(temp_prec_df$x, na.rm = TRUE))
data_ylim <- c(min(temp_prec_df$y, na.rm = TRUE), max(temp_prec_df$y, na.rm = TRUE))

# Calculate aspect ratio to ensure both maps match
data_aspect_ratio <- (data_ylim[2] - data_ylim[1]) / (data_xlim[2] - data_xlim[1])

# 5. BREAKS, PALETTE AND PLOT THEME
#----------------------------------

# create bivariate classes using biscale
breaks <- biscale::bi_class(
    temp_prec_df, x = temperature,
    y = precipitation, style = "fisher",
    dim = 3
)

# Define the color palette
pal <- "DkBlue"

# define a custom theme for the map
theme_for_the_win <- function(){
    theme_minimal() +
    theme(
        axis.title = element_blank(),
        plot.background = element_rect(
            fill = "white", color = NA
        ),
        plot.title = element_text(
            color = "grey10", hjust = 0.2,
            face = "bold", vjust = -1
        ),
        plot.subtitle = element_text(
            hjust = 0.2, vjust = -1
        ),
        plot.caption = element_text(
            size = 9, color = "grey20",
            hjust = .5, vjust = 1
        ),
        plot.margin = unit(c(0, 0, 0, 0), "lines"
        )
    )
}

# 6. 2D BIVARIATE MAP
#--------------------

# create the bivariate map using ggplot2
map <- ggplot(breaks) +
    geom_raster(
        aes(
            x = x, y = y, fill = bi_class
        ), show.legend = TRUE # FALSE
    ) +
    biscale::bi_scale_fill(
        pal = pal, dim = 3,
        flip_axes = TRUE, rotate_pal = FALSE
    ) +
    labs(
        title = "GREECE: Temperature and Precipitation",
        subtitle = "Average temperature and precipitation (1981-2010)",
        caption = "Source: CHELSA | Author: RealDataTalks",
        x = "", y = ""
    ) +
    coord_sf(
        crs = target_crs,
        xlim = data_xlim,
        ylim = data_ylim,
        expand = FALSE
    ) +
    theme_for_the_win() +
    theme(
        legend.position = c(1, 0),
        legend.justification = c(1, 0),
        legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
        legend.direction = "vertical"
    )

# create the legend for the bivariate map
legend <- biscale::bi_legend(
    pal = pal,
    flip_axes = TRUE,
    rotate_pal = FALSE,
    dim = 3,
    xlab = "Temperature (°C)",
    ylab = "Precipitation (mm)",
    size = 8
)

# Calculate plot dimensions based on aspect ratio for consistent proportions
base_width <- 7
plot_height <- base_width * data_aspect_ratio

# combine the map and legend using cowplot
# Move bivariate legend to upper right corner
full_map <- cowplot::ggdraw() +
    cowplot::draw_plot(
        plot = map, x = 0, y = 0,
        width = 1, height = 1
    ) +
    cowplot::draw_plot(
        plot = legend, x = .70, y = .70,
        width = .25, height = .25
    )

# display the final map with legend
print(full_map)

# save as PNG file with matching aspect ratio
ggsave(
    filename = "greece_bivariate_2d.png",
    width = base_width, height = plot_height, dpi = 600,
    device = "png", bg = "white", full_map
)

# 7. CREATE TERRAIN LAYER
#------------------------

# convert resampled DEM to dataframe (already projected and aligned)
dem_df <- as.data.frame(
    dem_resampled, xy = TRUE, na.rm = TRUE
)

# rename the third column to "dem"
names(dem_df)[3] <- "dem"

# Ensure DEM dataframe matches the exact same extent as climate data
dem_df <- dem_df[dem_df$x >= data_xlim[1] & dem_df$x <= data_xlim[2] &
                 dem_df$y >= data_ylim[1] & dem_df$y <= data_ylim[2], ]

# create the terrain layer map
dem_map <- ggplot(
    dem_df, aes(x = x, y = y, fill = dem)
) +
geom_raster() +
scale_fill_gradientn(colors = "white") +
guides(fill = "none") +
labs(
    title = "GREECE: Temperature and Precipitation",
    subtitle = "Average temperature and precipitation (1981-2010)",
    caption = "Source: CHELSA | Author: RealDataTalks"
) +
coord_sf(
    crs = target_crs,
    xlim = data_xlim,
    ylim = data_ylim,
    expand = FALSE
) +
theme_for_the_win() +
theme(legend.position = "none")

# 8. RENDER 3D SCENE
#-------------------

cat("Starting 3D rendering...\n")

# Optimize 3D rendering for limited resources
tryCatch({
    # Use smaller window size and scale to reduce memory usage
    rayshader::plot_gg(
        ggobj = full_map,
        ggobj_height = dem_map,
        width = base_width,
        height = plot_height,
        windowsize = c(400, round(400 * data_aspect_ratio)),  # Reduced from 600
        scale = 50,  # Reduced from 100 for less memory
        shadow = TRUE,
        shadow_intensity = 0.8,  # Slightly reduced
        phi = 87, theta = 0, zoom = .56,
        multicore = FALSE  # Disable multicore to reduce memory
    )
    
    cat("3D scene rendered successfully\n")
    
    # zoom out
    rayshader::render_camera(zoom = .6)
    
    # 9. LIGHTS
    #----------
    
    url <- "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/brown_photostudio_02_4k.hdr"
    hdri_file <- basename(url)
    
    # Only download if file doesn't exist
    if (!file.exists(hdri_file)) {
        cat("Downloading HDRI lighting file...\n")
        download.file(
            url = url,
            destfile = hdri_file,
            mode = "wb"
        )
    } else {
        cat("Using existing HDRI file\n")
    }
    
    # 10. RENDER 3D OBJECT
    #---------------------
    
    cat("Rendering high-quality 3D image...\n")
    
    # Use lower resolution to save disk space
    rayshader::render_highquality(
        filename = "greece-bivariate-3d.png",
        preview = TRUE,
        light = FALSE,
        environment_light = hdri_file,
        intensity = 1,
        rotate_env = 90,
        parallel = FALSE,  # Disable parallel to reduce memory
        width = 1200, height = round(1200 * data_aspect_ratio),  # Reduced from 2000
        interactive = FALSE
    )
    
    cat("3D map saved as: greece-bivariate-3d.png\n")
    
}, error = function(e) {
    cat("Warning: 3D rendering failed due to resource constraints:\n")
    cat(paste("Error:", conditionMessage(e), "\n"))
    cat("2D map (greece_bivariate_2d.png) was created successfully.\n")
    cat("To create 3D map, free up disk space (need ~3GB free).\n")
})

