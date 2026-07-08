"""
Fill remaining NaN cells in the area-comprometida-clipped 2025 fuel map using
iterative focal mode (small windows only), then re-clip to the exact study
area polygon to strip any cells filled outside its boundary.
"""
from pathlib import Path
import numpy as np
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from scipy.ndimage import uniform_filter

BASE = Path("C:/No_nube/fuel-type-prediction-ml/area_comprometida")
RASTER_IN = BASE / "KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif"
AOI_PATH = BASE / "area_comprometida.gpkg"
RASTER_OUT = BASE / "KitralFuelsDistribution_AngloRM_2025_areaComprometida_filled.tif"

WINDOW_SIZES = (3, 5)


def vectorized_focal_mode(filled, size):
    valid = ~np.isnan(filled)
    classes = np.unique(filled[valid])

    valid_count = uniform_filter(valid.astype(np.float32), size=size, mode="constant", cval=0.0)

    best_count = np.zeros(filled.shape, dtype=np.float32)
    best_class = np.full(filled.shape, np.nan, dtype=np.float32)

    for c in classes:
        count = uniform_filter((filled == c).astype(np.float32), size=size, mode="constant", cval=0.0)
        update = count > best_count
        best_count[update] = count[update]
        best_class[update] = c

    result = np.full(filled.shape, np.nan, dtype=np.float32)
    has_neighbors = valid_count > 0
    result[has_neighbors] = best_class[has_neighbors]
    return result


def main():
    print("Loading AOI (area comprometida)...")
    gdf = gpd.read_file(AOI_PATH)

    print(f"Loading raster: {RASTER_IN.name}")
    with rasterio.open(RASTER_IN) as src:
        arr = src.read(1).astype(np.float32)
        profile = src.profile.copy()
        transform = src.transform
        src_nodata = src.nodata
        crs = src.crs
        geoms = [geom.__geo_interface__ for geom in gdf.to_crs(crs).geometry]

    nan_mask = np.isnan(arr)
    if src_nodata is not None:
        nan_mask |= arr == src_nodata

    total_nan = int(nan_mask.sum())
    print(f"NaN cells before fill: {total_nan} ({100 * total_nan / arr.size:.3f}% of extent)")

    filled = arr.copy()
    remaining = nan_mask.copy()

    for size in WINDOW_SIZES:
        n_remaining = int(remaining.sum())
        if n_remaining == 0:
            break
        print(f"  Window {size}x{size}: {n_remaining} NaN cells remaining...")
        result = vectorized_focal_mode(filled, size)
        update = remaining & ~np.isnan(result)
        filled[update] = result[update]
        remaining = np.isnan(filled) & nan_mask

    leftover = int(remaining.sum())
    if leftover > 0:
        print(f"  WARNING: {leftover} cells still NaN after windows {WINDOW_SIZES} (isolated, no valid neighbors).")
    else:
        print("  All NaN cells filled within the given window sizes.")

    # --- Re-clip to the exact AOI polygon to strip any cells filled outside its boundary ---
    print("Re-clipping filled raster to the exact area-comprometida boundary...")
    tmp_profile = profile.copy()
    tmp_profile.update(dtype=rasterio.float32, nodata=np.nan, count=1)
    tmp_path = BASE / "_tmp_filled_prefinalclip.tif"
    with rasterio.open(tmp_path, "w", **tmp_profile) as dst:
        dst.write(filled.astype(np.float32), 1)

    with rasterio.open(tmp_path) as src:
        clipped, clipped_transform = mask(src, geoms, crop=True, nodata=np.nan)
    tmp_path.unlink()

    final = clipped[0]
    final_nan = int(np.isnan(final).sum())
    print(f"NaN cells after fill + re-clip: {final_nan} ({100 * final_nan / final.size:.3f}% of cropped extent)")

    out = final.copy()
    out[np.isnan(out)] = -9999.0
    profile.update(
        driver="GTiff",
        dtype=rasterio.int16,
        nodata=-9999,
        transform=clipped_transform,
        height=final.shape[0],
        width=final.shape[1],
        count=1,
        compress="lzw",
    )
    with rasterio.open(RASTER_OUT, "w", **profile) as dst:
        dst.write(out.astype(np.int16), 1)

    print(f"Saved: {RASTER_OUT}")


if __name__ == "__main__":
    main()
