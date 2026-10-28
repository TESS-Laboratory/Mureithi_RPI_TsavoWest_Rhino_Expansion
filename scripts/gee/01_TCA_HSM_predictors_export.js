/**
 * 01_TCA_HSM_predictors_export.js
 * Project : Tsavo West Rhino Expansion + Tsavo cheetah - Habitat Suitability Models
 * Author  : Isaac Mureithi (AWF / OPALS, Univ. of Exeter)
 * Written : 2026-10-28      GEE account: ee-imnduta1
 * Save as : users/imnduta1/Ismurn/TsavoHSM/01_TCA_HSM_predictors_export
 *
 * PURPOSE
 *   Extra predictor layers for the habitat suitability models in
 *   RPI_TsavoWest_Rhino_Expansion_Script.Rmd (Section 5): rainfall and its year-to-year
 *   variability (CHIRPS), vegetation greenness (MODIS NDVI) and surface water (JRC).
 *   GEE holds no species records, so the models themselves are fitted in R; GEE only
 *   supplies predictors. One export covers both the Tsavo West rhino model and the
 *   Tsavo Conservation Area (TCA) cheetah model.
 *
 * INPUTS
 *   UCSB-CHG/CHIRPS/DAILY        precipitation (mm / day), ~5.5 km
 *   MODIS/061/MOD13Q1            NDVI (x 0.0001), 250 m, SummaryQA <= 1 (same QC as the Amaka scripts)
 *   JRC/GSW1_4/GlobalSurfaceWater  occurrence (%), seasonality (months), 30 m
 *
 * OUTPUTS  (Drive folder TsavoHSM_GEE_Exports/  ->  download into data/gee_exports/)
 *   chirps_rain_<y0>_<y1>.tif      bands rain_annual_mm (mean annual total, mm), rain_cv (inter-annual CV),
 *                                  rain_dry_mm (mean DRY-season total, mm)
 *   modis_ndvi_<y0>_<y1>.tif       bands ndvi_mean (all dates), ndvi_dry_mean (DRY-season dates)
 *   jrc_surface_water_90m.tif      bands water_any (occurrence >= 10 %), water_perm (water >= 10 months/yr); 0/1
 *   R reads them in build_hsm_predictors() (rainfall, NDVI) and water_distance_km() (water -> distance in km).
 *
 * SEASONS (same as the Amaka project; months of the SAME calendar year)
 *   LR Mar-May | SR Oct-Dec | DRY Jan-Feb + Jun-Sep
 *
 * EXPORT SETTINGS
 *   EPSG:32737 (UTM 37S, metres), each product at its native scale: CHIRPS 5566 m, NDVI 250 m.
 *   JRC water is exported at 90 m (3 x native 30 m, max-aggregated so thin rivers survive) to keep
 *   the file small; R aggregates it to the 500 m model grid.
 *   Run each of the queued tasks from the Tasks tab.
 * ----------------------------------------------------------------------------
 */

// ---- 1. CONFIG (edit here) -----------------------------------------------------
var AOI_BOX      = [37.5, -4.8, 39.6, -1.4];   // lon/lat envelope of the TCA (Kenya side) + ~25 km pad
var YEAR_START   = 2010;                       // clamped to years the dataset fully covers
var YEAR_END     = 2024;
var EXPORT_CRS   = 'EPSG:32737';
var DRIVE_FOLDER = 'TsavoHSM_GEE_Exports';
var RUN_EXPORTS  = true;                       // false = preview only, no tasks created
var DRY_MONTHS   = [1, 2, 6, 7, 8, 9];

// ---- 2. AOI -----------------------------------------------------------------------------
var envelope = ee.Geometry.Rectangle(AOI_BOX, 'EPSG:4326', false);

// ---- 3. HELPERS (same as in the Amaka seasonal scripts) --------------------------------------
var TASKS_QUEUED = 0;

function seq(a, b) {
  var out = [];
  for (var i = a; i <= b; i++) { out.push(i); }
  return out;
}

function monthFilter(months) {
  var fs = months.map(function (m) { return ee.Filter.calendarRange(m, m, 'month'); });
  return fs.length === 1 ? fs[0] : ee.Filter.or.apply(null, fs);
}

// Years in [YEAR_START, YEAR_END] that the collection covers completely, so a half
// year can never be exported as if it were a full season.
function effectiveYears(coll) {
  var tmin = new Date(coll.aggregate_min('system:time_start').getInfo());
  var tmax = new Date(coll.aggregate_max('system:time_start').getInfo());
  var first = tmin.getUTCFullYear() + ((tmin.getUTCMonth() > 0 || tmin.getUTCDate() > 20) ? 1 : 0);
  var last  = tmax.getUTCFullYear() - (tmax.getUTCMonth() < 11 ? 1 : 0);
  var y0 = Math.max(YEAR_START, first);
  var y1 = Math.min(YEAR_END, last);
  if (y1 < y0) { throw new Error('No complete years between ' + YEAR_START + ' and ' + YEAR_END); }
  print('Years exported (requested ' + YEAR_START + '-' + YEAR_END + '):', y0 + '-' + y1);
  return seq(y0, y1);
}

function queueExport(img, name, scale) {
  TASKS_QUEUED += 1;
  if (!RUN_EXPORTS) { return; }
  Export.image.toDrive({
    image:          img,
    description:    name,
    folder:         DRIVE_FOLDER,
    fileNamePrefix: name,
    region:         envelope,
    crs:            EXPORT_CRS,
    scale:          scale,
    maxPixels:      1e10,
    fileFormat:     'GeoTIFF'
  });
}

// ---- 4. RAINFALL (CHIRPS) ---------------------------------------------------------------------
var chirps  = ee.ImageCollection('UCSB-CHG/CHIRPS/DAILY').select('precipitation');
var yearsC  = effectiveYears(chirps);

// Total rain (mm) of one calendar year, optionally restricted to some months. SUM: daily depths in mm.
function yearlyRain(y, months) {
  var c = chirps.filter(ee.Filter.calendarRange(y, y, 'year'));
  if (months) { c = c.filter(monthFilter(months)); }
  return c.sum().set('year', y);
}

var rainAnnual = ee.ImageCollection(yearsC.map(function (y) { return yearlyRain(y, null); }));
var rainDry    = ee.ImageCollection(yearsC.map(function (y) { return yearlyRain(y, DRY_MONTHS); }));

var chirpsStack = ee.Image.cat([
  rainAnnual.mean().rename('rain_annual_mm'),
  rainAnnual.reduce(ee.Reducer.stdDev()).divide(rainAnnual.mean()).rename('rain_cv'),
  rainDry.mean().rename('rain_dry_mm')
]).toFloat();

// ---- 5. VEGETATION GREENNESS (MODIS NDVI) ------------------------------------------------------
var modisRaw = ee.ImageCollection('MODIS/061/MOD13Q1');
var yearsN   = effectiveYears(modisRaw);

var ndvi = modisRaw
  .filterDate(yearsN[0] + '-01-01', (yearsN[yearsN.length - 1] + 1) + '-01-01')
  .map(function (im) {
    var ok = im.select('SummaryQA').lte(1);   // good or marginal data only
    return im.select('NDVI').multiply(0.0001).updateMask(ok).rename('ndvi')
             .copyProperties(im, ['system:time_start']);
  });

var ndviStack = ee.Image.cat([
  ndvi.mean().rename('ndvi_mean'),
  ndvi.filter(monthFilter(DRY_MONTHS)).mean().rename('ndvi_dry_mean')
]).toFloat();

// ---- 6. SURFACE WATER (JRC Global Surface Water) --------------------------------------------------
var gsw       = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');
var waterAny  = gsw.select('occurrence').unmask(0).gte(10).rename('water_any');      // water seen in >= 10 % of observations
var waterPerm = gsw.select('seasonality').unmask(0).gte(10).rename('water_perm');    // water present >= 10 months of the year
var water90m  = ee.Image.cat([waterAny, waterPerm]).toByte()
                  .reduceResolution({reducer: ee.Reducer.max(), maxPixels: 256})
                  .reproject({crs: EXPORT_CRS, scale: 90});

// ---- 7. PREVIEW ---------------------------------------------------------------------------------
Map.centerObject(envelope, 8);
Map.setOptions('HYBRID');
Map.addLayer(chirpsStack.select('rain_annual_mm').clip(envelope),
             {min: 200, max: 900, palette: ['#fff7bc', '#41b6c4', '#081d58']}, 'Mean annual rain (mm)');
Map.addLayer(ndviStack.select('ndvi_dry_mean').clip(envelope),
             {min: 0.1, max: 0.6, palette: ['#a6611a', '#f5f5f5', '#018571']}, 'Dry-season NDVI');
Map.addLayer(water90m.select('water_any').selfMask().clip(envelope), {palette: ['0000ff']}, 'Surface water (JRC)');
Map.addLayer(ee.Image().byte().paint({featureCollection: ee.FeatureCollection([ee.Feature(envelope)]), color: 1, width: 2}),
             {palette: 'ff8800'}, 'Export envelope');

// Plausibility checks: read these in the Console BEFORE exporting.
// Tsavo should show roughly 250-800 mm/yr mean annual rain and NDVI of 0.2-0.6 in the dry season.
print('Mean annual rain over the envelope (mm):',
      chirpsStack.select('rain_annual_mm').reduceRegion({reducer: ee.Reducer.mean(), geometry: envelope, scale: 5566, maxPixels: 1e9}));
print('Dry-season NDVI over the envelope:',
      ndviStack.select('ndvi_dry_mean').reduceRegion({reducer: ee.Reducer.mean(), geometry: envelope, scale: 1000, maxPixels: 1e9}));

// ---- 8. EXPORT ----------------------------------------------------------------------------------
queueExport(chirpsStack, 'chirps_rain_' + yearsC[0] + '_' + yearsC[yearsC.length - 1], 5566);
queueExport(ndviStack,   'modis_ndvi_'  + yearsN[0] + '_' + yearsN[yearsN.length - 1], 250);
queueExport(water90m,    'jrc_surface_water_90m', 90);
print('Export tasks queued - run each from the Tasks tab:', TASKS_QUEUED);
