# Habitat Intelligence Framework for Black Rhino Expansion in Tsavo West National Park (RPI, terrain and habitat suitability models)

This repository contains the data and code used to reproduce the analyses, figures and tables presented in:

[Mureithi I.N., Author B. & Author C. (Year). Title. Journal / thesis / report. DOI: https://doi.org/... - to be added]

A permanent version of this repository is archived at [DOI - to be added once a release is archived, e.g. on Zenodo]

Use of this code is licensed under Licence: [![Licence: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0).

Contact Isaac Nduta Mureithi at [IMureithi@awf.org / I.N.Mureithi@exeter.ac.uk] (ORCID: [[ORCID iD](https://orcid.org/0009-0009-2318-2568)]).

## Project overview

This project asks whether Tsavo West National Park (Kenya) can support an expansion of its black rhino (*Diceros bicornis*) population beyond the current Rhino Range (Ngulia Sanctuary and the Intensive Protection Zone, IPZ). It combines the Relative Productivity Index (RPI, developed by Guy Lomax, University of Exeter/TESS Lab) with PML_V2 water-energy fluxes, land cover, terrain and hydrology to explain the productivity gap between the managed Rhino Range and the rest of the park, and then builds habitat suitability models for black rhino (Tsavo West) and cheetah (*Acinonyx jubatus*, Tsavo Conservation Area). The repository holds the R workflow, the supporting boundary and terrain data, and a Google Earth Engine script for additional predictors. The work was developed by Isaac Nduta Mureithi through the African Wildlife Foundation - University of Exeter partnership.

## Repository contents

### Scripts

| Script | Description |
|---|---|
| *scripts/Mureithi_Tsavo_Habitat_Intelligence.Rmd* | The full workflow as one R Markdown file, organised in sections (table below). Run its chunks in order. |
| *scripts/gee/01_TCA_HSM_predictors_export.js* | Google Earth Engine script that exports CHIRPS rainfall, MODIS NDVI and JRC surface-water layers to Google Drive for Section 5. Optional; run it first if you want these predictors. |

Sections of *Mureithi_Tsavo_Habitat_Intelligence.Rmd*:

| Section | Description |
|---|---|
| Setup | Loads packages, defines project paths, imports the RPI, boundary and zone data, and maps the study area. |
| Preliminary | Maps RPI temporal performance (MAE, RMSE, R²), PML_V2 fluxes and land cover across Kenya, with Tsavo West and the Rhino Range outlined. |
| 1. Zone-level RPI summaries | Extracts pixel values per zone (Tsavo West, Ngulia, IPZ, Rhino Range, Tsavo West excluding the Rhino Range) and builds a combined RPI, PML_V2 and land cover profile for each zone. |
| 2. Temporal trend analysis | Theil-Sen slopes, Mann-Kendall tests and 5-year rolling means of RPI at zone and pixel level; trend maps. |
| 3. Habitat gap analysis | Figures comparing the Rhino Range with the rest of the park: RPI distributions, annual time series, gap trajectory and a spatial gap map. |
| 4A. Land cover × RPI | Relates RPI to shrubland, grassland, tree and bare cover and to PML_V2 fluxes (point-sampled at RPI pixel locations). |
| 4B. Terrain and hydrology | Derives slope, ruggedness (TRI), wetness (TWI), stream network and distance to water from an SRTM DEM (WhiteboxTools), with maps and figures. |
| 5. Habitat suitability models | Random-forest habitat suitability for black rhino (Tsavo West) and cheetah (Tsavo Conservation Area), including candidate rhino expansion areas. |

### Data

Included in the repository (*data/*):

| File or folder | Description |
|---|---|
| *data/Country_Borders/* | Africa, Kenya and administrative boundaries, Kenya terrestrial protected areas, and *ken_pd_2020_1km.tif* (population density, 1 km). The script uses the Africa, Kenya admin and protected-area layers and the population raster. |
| *data/WDPA_Amboseli_Tsavo/* | World Database on Protected Areas polygons (April 2025) for national parks, reserves and community areas in the Amboseli–Tsavo landscape. The script uses Tsavo West and Chyulu Hills. |
| *data/TsavoWest_Rhino_Zones/* | Boundaries of Ngulia Sanctuary and the Tsavo West Intensive Protection Zone (the Rhino Range). |
| *data/Tsavo_Conservation_Areas/* | Tsavo Conservation Area parks (*TCAFInal.shp*, shipped without a projection file; coordinates are UTM 37S) and the TTWCA ranches (*RanchesTTWCA.shp*). The script uses these two layers. |
| *data/Amboseli_Conservation_Areas/* | Amboseli conservancies and other conserved areas (supporting layers, not used by the current script). |
| *data/Terrain/* | *TsavoWest_DEM.tif* (SRTM, about 76 m) and the WhiteboxTools outputs in *WBT/* (breached and filled DEM, specific catchment area, slope, TWI). |
| *plots/* | Maps saved from earlier runs of the workflow. |

Not included in the repository:

| File | Description | Why it is not included |
|---|---|---|
| *rpi_ea_v2.tif*, *actual_gpp_ea_v2.tif*, *potential_gpp_ea_v2.tif*, *rpi_ea_temporal_performance.tif* | RPI datasets for East Africa (Guy Lomax): RPI, actual and potential GPP, and RPI quality layers (MAE, RMSE, R²). Only *rpi_ea_v2.tif* and *rpi_ea_temporal_performance.tif* are read by the script. | Large rasters held outside the repository; [confirm: file size and/or data-sharing arrangement; say where they can be obtained]. |
| *PML_V2_Kenya_Drive_Export.tif*, *studyPixels_Kenya_Export.tif* | PML_V2 mean GPP, canopy transpiration, soil evaporation and interception; and land cover (IGBP class and tree, shrub, grass and bare-ground fractions) for Kenya, exported from Google Earth Engine. | Large rasters held outside the repository; [confirm: where they can be obtained or regenerated]. |
| *data/Species/* | Precise rhino and cheetah records (optional input) and cached GBIF downloads. | Precise locations of threatened species are poaching-sensitive. Instead, the script downloads public GBIF records itself; these are mostly obscured by their providers (see Section 5 below). |
| *data/gee_exports/* | GeoTIFFs downloaded from Google Drive after running the Earth Engine script. | Reproducible by running *scripts/gee/01_TCA_HSM_predictors_export.js*. |
| *data/Terrain/TCA_DEM.tif* | SRTM DEM for the Tsavo Conservation Area. | Downloaded automatically by Section 5 on first run. |
| *outputs/HSM/* | Habitat suitability rasters and tables (listed below). | Written when Section 5 is run. Only the rasters should be shared, never point locations. |

The three raster paths for RPI, PML_V2 and StudyPixels are written as absolute paths in the data-import chunks of the script; edit them to point to your copy.

Outputs of Section 5 (*outputs/HSM/*): *rhino_TsavoWest_HSI_mean.tif* (mean suitability, 0–1), *rhino_TsavoWest_HSI_sd.tif* (spread across the 10 runs), *rhino_TsavoWest_suitable.tif* (suitable / not suitable), *rhino_TsavoWest_metrics.csv* (accuracy per run), *rhino_TsavoWest_zone_summary.csv*, *rhino_TsavoWest_expansion_candidates.csv*, and *cheetah_TCA_prior_HSI_mean.tif*, *cheetah_TCA_prior_suitable.tif* and *cheetah_TCA_prior_zone_summary.csv* (named *cheetah_TCA_occurrences_...* when the cheetah model is fitted from records).

### Habitat suitability models (Section 5)

- **Grid and method:** a 500 m grid in UTM 37S. Random-forest probability models with 10 repetitions, spatial-block training/testing splits and balanced pseudo-absences, following the Google Earth Engine case studies of Crego et al. (2022), translated to R. Accuracy is reported as AUC-ROC, AUC-PR and the threshold that maximises sensitivity + specificity.
- **Species records:** GBIF holds recent rhino and cheetah records for Tsavo, but almost all are iNaturalist observations with deliberately obscured coordinates (about 31 km uncertainty; checked on 2026-10-28). They are too coarse for a 500 m model and are used only after strict cleaning, as a supplement and reality check.
- **Black rhino:** presences are every cell of the occupied Rhino Range (Ngulia Sanctuary + IPZ). The result is a habitat-similarity map: where the rest of the park resembles current rhino habitat, not where rhinos would choose to live. Candidate expansion areas are suitable cells within 5 km of water.
- **Cheetah:** uses precise records (*data/Species/cheetah_occurrences.csv* with columns *lon*, *lat*, *year*, *uncertainty_m*) once at least 30 are supplied; until then an editable expert-prior index is mapped. The index is illustrative and has not been validated.
- **Status:** first version. Precise records from KWS/AWF are the main upgrade.

## Getting started

Clone this repository and open *Mureithi_RPI_TsavoWest_Rhino_Expansion.Rproj* in RStudio. The project was developed with R 4.4.1 and tmap 4.1 (R 4.2 or later and tmap 4.x are required). Missing packages are installed on first run with *pacman*.

No *renv.lock* file is included yet, so package versions are not pinned. When one is added, restore the environment before running any analysis:

```r
renv::restore()
```

## Running the analysis

1. (Optional) Run *scripts/gee/01_TCA_HSM_predictors_export.js* in the Google Earth Engine Code Editor and start each export task from the Tasks tab. Download the files from the Drive folder *TsavoHSM_GEE_Exports* into *data/gee_exports/*. Without them, Section 5 runs on the layers already in the project.
2. Edit the three absolute raster paths (RPI, PML_V2, StudyPixels) in the data-import chunks of *Mureithi_Tsavo_Habitat_Intelligence.Rmd*.
3. Run the chunks of *Mureithi_Tsavo_Habitat_Intelligence.Rmd* in order from the top. Later sections use objects created earlier. WhiteboxTools downloads its binary (about 50 MB) on first use, and the terrain and hydrology processing in Section 4B is the slowest step.

## Funding and acknowledgements

[Nature Path grant to African Wildlife Foundation.]

RPI datasets: Guy Lomax (University of Exeter/TESS Lab). Park boundaries: World Database on Protected Areas (WDPA, April 2025). Rhino Range boundaries (Ngulia Sanctuary and the Intensive Protection Zone): [source, e.g. Kenya Wildlife Service; Taita Taveta Wildlife Conservancies Association].

Other data and methods: PML_V2 (Zhang et al., 2019); CHIRPS (Funk et al., 2015); MODIS MOD13Q1 v061 (Didan, 2021); JRC Global Surface Water (Pekel et al., 2016); species records from GBIF (www.gbif.org), including iNaturalist research-grade observations (CC BY-NC); modelling approach after Crego, Stabach & Connette (2022), *Diversity and Distributions*.
