# Open after running .rmd file.

### 5.3 Exporting extra predictors from Google Earth Engine (optional)

The models above run on the layers already in this project. Rainfall (CHIRPS), vegetation greenness (MODIS NDVI) and surface-water distance (JRC) are exported from GEE with `scripts/gee/01_TCA_HSM_predictors_export.js`, using the same convention as the Amaka and Kitobo projects:
  
  Once you run the GEE script, the files appear in the Drive folder `TsavoHSM_GEE_Exports/`. Download them into `data/gee_exports/`.Re-run Steps 7 and 13: `build_hsm_predictors()` picks the files up automatically (adds rainfall, rainfall variability, NDVI, and replaces the stream-based water distance with distance to JRC surface water).

### 5.4 Next steps

- **Real cheetah and rhino records** (KWS / AWF / SMART / camera traps / collars) are the biggest upgrade: they switch both species to a fully data-driven, validated model.
- **Movement and connectivity**: the cheetah HSI can be inverted into a resistance surface (`1 - HSI`) for least-cost corridors between the parks (`gdistance` or `circuitscape`).
- **Time**: the GEE case study 2 matches each record to the closest-in-time image. The RPI stack has 23 yearly layers, so the same idea can be applied here once records have dates.