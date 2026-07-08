library(sf)

base <- "G:/Mi unidad/F2A/[01] Proyectos y Postulaciones/[01] Proyectos/Anglo American - SOFOFA/datos/area_estudio"

for (f in c("roi_suroeste.gpkg", "RM_SN.gpkg", "RM_SN_bf.gpkg", "nogales.gpkg", "nogales_bf.gpkg")) {
  path <- file.path(base, f)
  cat("=====", f, "=====\n")
  x <- st_read(path, quiet = TRUE)
  cat("CRS:", st_crs(x)$input, "| N features:", nrow(x), "| Cols:", paste(names(x), collapse=", "), "\n")
  print(st_drop_geometry(x))
  cat("Area total (ha):", round(sum(as.numeric(st_area(x))) / 10000, 1), "\n\n")
}
