# Mureithi_RPI_Habitat_Intelligence_Framework_Rhino_Expansion

This repository contains R scripts and data developed by Isaac Nduta Mureithi through the African Wildlife Foundation - University of Exeter partnership, building upon the RPI methodology developed by Guy Lomax. Contact information (IMureithi@awf.org / I.N.Mureithi@exeter.ac.uk).

**Repository Overview**
The main R scripts in this repository provide a complete workflow for:

• Data Integration: Harmonising RPI datasets with PML_V2 productivity/flux layers and MODIS land cover data.

• Spatial Processing: Zonal extraction of pixel-level values for Ngulia Sanctuary, the Intensive Protection Zone (IPZ), and the broader Tsavo West ecosystem.

• Trend Analysis: Long-term vegetation trajectory estimation using Theil-Sen slope analysis and 5-year rolling means to separate climatic noise from management signals.

• Habitat Gap Analysis: Comparative visualisation and statistical profiling of "managed" vs "unmanaged" zones to quantify the productivity premium of the Rhino Range.

• Land Cover and Terrain Cross-Analysis: Sampling PMLv2, land cover, terrain (slope, ruggedness, wetness) and hydrology (distance to water) at RPI pixel locations to explain *why* the productivity gap between the Rhino Range and the rest of Tsavo West exists.

• Habitat Suitability Models (HSM): Random-forest habitat suitability maps for black rhino in Tsavo West National Park and cheetah across the Tsavo Conservation Area (TCA), including candidate rhino expansion areas (see "Habitat Suitability Models" below).

The analysis uses libraries including sf, terra, tidyverse, tmap (v4), trend, slider, whitebox, elevatr, rgbif and ranger for spatial data processing, statistical analysis, habitat modelling and publication-quality mapping.

**Data Description**
1. RPI Datasets
   
• actual_gpp_ea_v2.tif: Integrated annual GPP estimates for 22 hydrological years (2000–2023).

• potential_gpp_ea_v2.tif: Estimated potential GPP based on quantile regression forest modeling.

• rpi_ea_v2.tif: The Relative Productivity Index values (Ratio of Actual/Potential GPP).

• rpi_ea_temporal_performance.tif: Pixel-level quality control layers (MAE, RMSE, R^2).

2. Mechanistic Context (PML_V2) - used to characterise the eco-hydrological drivers of habitat quality
   
• Productivity and water flux layers including Canopy Transpiration (E_c).

• Soil Evaporation (E_s).

• Interception (E_i).

3. Habitat Characterisation (Study Pixels)
   
• Land cover classification (IGBP - MODIS)

• Fractional cover percentages of Trees, Shrub, Grass and Bare Ground (ESA) used to define the vegetation structure underlying RPI patterns.

4. Terrain & Hydrology
   
• SRTM Digital Elevation Model: (~76m resolution) used to define the baseline elevation profile across the 9,065 $\text{km}^2$ expansion area.

• Slope (Slope_deg), Directional Aspect (Aspect_Class), and Terrain Ruggedness Index (TRI): used to model large mammal movement costs and solar/moisture dynamics.

•Topographic Wetness Index (TWI) & SCA: hydro-enforced layers mapping steady-state soil moisture distribution and upslope water accumulation paths across the landscape.

•Water Proximity (Stream & Dist_to_Water_km): a binary seasonal drainage network (mapping crucial ephemeral luggas) paired with a continuous distance matrix tracking exact kilometer proximity to the nearest water security line—a primary driver for black rhino ranging patterns.

5. Google Earth Engine Predictors (optional)

• CHIRPS rainfall (mean annual total, inter-annual variability, dry-season total), MODIS NDVI (mean and dry-season mean) and JRC Global Surface Water, exported with `scripts/gee/01_TCA_HSM_predictors_export.js` to the Drive folder `TsavoHSM_GEE_Exports` (EPSG:32737, each product at its native scale) and downloaded into `data/gee_exports/`.

6. Species Records

• Precise occurrence records (`data/Species/<species>_occurrences.csv` with columns lon, lat, year, uncertainty_m) and GBIF downloads. These are sensitive and are not tracked in this repository.

**Repository Structure**

• `scripts/RPI_TsavoWest_Rhino_Expansion_Script.Rmd`: the full workflow (Sections 1–5).

• `scripts/gee/`: Google Earth Engine script that exports extra predictor layers to Google Drive.

• `data/`: boundaries, terrain and hydrology layers used by the script.

• `plots/`: saved figures.

• Not tracked in Git (see `.gitignore`): `data/Species/`, `data/gee_exports/`, `outputs/` (HSM rasters and tables) and the downloaded `data/Terrain/TCA_DEM.tif`.

**How to Run**

• Open `Mureithi_RPI_TsavoWest_Rhino_Expansion.Rproj` in RStudio (R 4.2 or later; tmap 4.x). Missing packages are installed by `pacman` on first run.

• The RPI, PMLv2 and StudyPixels rasters are large and are not stored in the repository. Edit the file paths in the data-import chunks to point to your copy.

• Run the chunks in order from the top: later sections use objects created earlier. WhiteboxTools downloads its binary (~50 MB) on the first run.

• Section 5 can use the Earth Engine exports if they are present in `data/gee_exports/`; without them it runs on the layers already in the project.

**Habitat Suitability Models (Section 5)**

• Study areas: Tsavo West National Park (black rhino) and the Kenyan side of the Tsavo Conservation Area (cheetah), on a 500 m grid in UTM 37S.

• Method: random-forest probability models with 10 repetitions, spatial-block training/testing splits and balanced pseudo-absences, following the Google Earth Engine case studies of Crego et al. (2022), translated to R. Accuracy is reported as AUC-ROC, AUC-PR and the threshold that maximises sensitivity + specificity.

• Species records: GBIF holds recent rhino and cheetah records for Tsavo, but almost all are iNaturalist observations with deliberately obscured coordinates (about 31 km uncertainty; checked on 2026-10-28). They are too coarse for a 500 m model and are used only after strict cleaning, as a supplement and reality check.

• Black rhino: presences are the occupied Rhino Range (Ngulia Sanctuary + IPZ). The model is therefore a habitat-similarity model: it shows where the rest of the park resembles current rhino habitat, not where rhinos would choose to live. Candidate expansion areas are cells that are suitable and within 5 km of water.

• Cheetah: uses precise records when at least 30 are supplied; until then an editable expert-prior index is mapped. This index is illustrative and unvalidated.

• Outputs are written to `outputs/HSM/` (suitability and uncertainty rasters, metrics and zone summaries). Precise rhino and cheetah locations are poaching-sensitive: share only the rasters, never the points.

• Status: first version. Precise KWS/AWF records are the main planned upgrade.

**Data Provenance**
The reproducible code is available on GitHub under the [![Licence: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0). National Park boundaries were sourced from the World Database on Protected Areas (WDPA, April 2025). Rhino Range boundaries (Ngulia Sanctuary and the Intensive Protection Zone) were sourced from [your source, e.g. KWS / Tsavo Conservation Area]. The RPI datasets are attributed to Guy Lomax (University of Exeter/TESS Lab).

Other data and methods: PML_V2 (Zhang et al., 2019); CHIRPS (Funk et al., 2015); MODIS MOD13Q1 v061 (Didan, 2021); JRC Global Surface Water (Pekel et al., 2016); species records from GBIF (www.gbif.org), including iNaturalist research-grade observations (CC BY-NC); habitat modelling approach after Crego, Stabach & Connette (2022), Diversity and Distributions.
