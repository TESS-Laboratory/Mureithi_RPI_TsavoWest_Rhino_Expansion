# Mureithi_RPI_Habitat_Intelligence_Framework_Rhino_Expansion

This repository contains R scripts and data developed by Isaac Nduta Mureithi through the African Wildlife Foundation - University of Exeter partnership, building upon the RPI methodology developed by Guy Lomax.

**Repository Overview**
The main R scripts in this repository provide a complete workflow for:

• Data Integration: Harmonising RPI datasets with PML_V2 productivity/flux layers and MODIS land cover data.

• Spatial Processing: Zonal extraction of pixel-level values for Ngulia Sanctuary, the Intensive Protection Zone (IPZ), and the broader Tsavo West ecosystem.

• Trend Analysis: Long-term vegetation trajectory estimation using Theil-Sen slope analysis and 5-year rolling means to separate climatic noise from management signals.

• Habitat Gap Analysis: Comparative visualisation and statistical profiling of "managed" vs "unmanaged" zones to quantify the productivity premium of the Rhino Range.

The analysis uses libraries including sf, terra, tidyverse, tmap, trend, and slider for spatial data processing, statistical analysis, and publication-quality mapping.

**Data Description**
1. RPI Datasets
• actual_gpp_ea_v2.tif: Integrated annual GPP estimates for 22 hydrological years (2000–2023).
• potential_gpp_ea_v2.tif: Estimated potential GPP based on quantile regression forest modeling.
• rpi_ea_v2.tif: The Relative Productivity Index values (Ratio of Actual/Potential GPP).
• rpi_ea_temporal_performance.tif: Pixel-level quality control layers (MAE, RMSE, R^2).

2. Mechanistic Context (PML_V2)
• Productivity and water flux layers including Canopy Transpiration (E_c), Soil Evaporation (E_s), and Interception (E_i), used to characterise the eco-hydrological drivers of habitat quality.

4. Habitat Characterisation (Study Pixels)
• Land cover classification (IGBP) and fractional cover percentages (Trees, Shrub, Grass, Bare Ground) used to define the vegetation structure underlying RPI patterns.

**Data Provenance**
The reproducible code is available on GitHub under a [e.g., MIT or GNU GPL V3] license. National Park and Sanctuary boundaries were sourced from [Source, e.g., KWS/WDPA]. The RPI datasets are attributed to Guy Lomax (University of Exeter/TESS Lab).
