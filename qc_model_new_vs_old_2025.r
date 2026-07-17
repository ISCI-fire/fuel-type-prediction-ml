# QC comparativo EJE-MODELO: modelo nuevo (EVI + distancia + CV espacial) vs
# modelo viejo (v1), ambos aplicados a la temporada 2025, dentro del area
# oficialmente comprometida (roi_suroeste + Los Nogales).
#
# Aisla el efecto del reentrenamiento (mismas imagenes satelitales 2025).
# Foco: confusiones documentadas (BN03<->MT01, PL01 sobre matorral/pastizal),
# el error BN01 (Alerce, no existe en la RM) y la explosion de PCH1.

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(data.table)

OUT <- "area_comprometida"
lookup <- fread("kitral_lookup_table-modified.csv")
lookup <- lookup[!is.na(grid_value)]
name_of <- function(ft) lookup[match(ft, fuel_type), descriptive_name]

r_old <- rast(file.path(OUT, "v1_model_backup", "KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif"))
r_new <- rast(file.path(OUT, "KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif"))
px <- prod(res(r_new)) / 10000

con <- file(file.path(OUT, "QC_REPORT_modelo_nuevo_vs_viejo_2025.md"), open = "wt", encoding = "UTF-8")
w <- function(...) writeLines(sprintf(...), con)

w("# QC comparativo: modelo NUEVO vs VIEJO (temporada 2025, area comprometida)")
w("")
w("Ambos mapas usan las mismas imagenes satelitales 2025-2026; la unica diferencia")
w("es el modelo (reentrenado con EVI + distancia a especies + CV espacial vs v1).")
w("Area de pixel: %.4f ha. Fuente viejo: v1_model_backup/. Fuente nuevo: area_comprometida/.", px)
w("")

# ---- 1. Matriz de transicion viejo -> nuevo ----
stk <- c(r_old, r_new)
names(stk) <- c("viejo", "nuevo")
ct <- as.data.table(as.data.frame(crosstab(stk, useNA = FALSE)))
setnames(ct, c("v_old", "v_new", "count"))
ct[, v_old := as.integer(as.character(v_old))]
ct[, v_new := as.integer(as.character(v_new))]
ct <- merge(ct, lookup[, .(grid_value, fuel_old = fuel_type)], by.x = "v_old", by.y = "grid_value", all.x = TRUE)
ct <- merge(ct, lookup[, .(grid_value, fuel_new = fuel_type)], by.x = "v_new", by.y = "grid_value", all.x = TRUE)
ct[, area_ha := count * px]
ct <- ct[order(-count)]
fwrite(ct, file.path(OUT, "transition_matrix_modelo_nuevo_vs_viejo_2025.csv"))

tot <- sum(ct$count)
same <- sum(ct[fuel_old == fuel_new]$count)
chg <- tot - same
w("## 1. Estabilidad global entre modelos")
w("")
w("- Pixeles comparables: %s", format(tot, big.mark = "."))
w("- Misma clase viejo->nuevo: %s (%.1f%%)", format(same, big.mark = "."), 100 * same / tot)
w("- Cambio de clase viejo->nuevo: %s (%.1f%%)", format(chg, big.mark = "."), 100 * chg / tot)
w("")
w("## 2. Top 20 transiciones (excluyendo 'sin cambio')")
w("")
w("| viejo | nuevo | area_ha | %% del total |")
w("|---|---|---:|---:|")
top <- head(ct[fuel_old != fuel_new], 20)
for (i in seq_len(nrow(top))) {
  w("| %s | %s | %s | %.2f |", top$fuel_old[i], top$fuel_new[i],
    format(round(top$area_ha[i]), big.mark = "."), 100 * top$count[i] / tot)
}
w("")

# ---- 3. Foco en las confusiones documentadas ----
class_area <- function(r, ft) {
  gv <- lookup[fuel_type == ft, grid_value]
  sum(values(r) == gv, na.rm = TRUE) * px
}
w("## 3. Clases clave: area (ha) viejo vs nuevo")
w("")
w("| clase | descripcion | viejo | nuevo | delta |")
w("|---|---|---:|---:|---:|")
for (ft in c("BN03", "MT01", "PL01", "BN01", "PCH1", "PCH5", "MT02", "BN04", "MT06", "SV03")) {
  ao <- class_area(r_old, ft); an <- class_area(r_new, ft)
  w("| %s | %s | %s | %s | %+.0f |", ft, name_of(ft),
    format(round(ao), big.mark = "."), format(round(an), big.mark = "."), an - ao)
}
w("")

# ---- 4. BN01 (Alerce): de donde salio y su distancia al Alerce ----
gv_bn01 <- lookup[fuel_type == "BN01", grid_value]
w("## 4. BN01 (Alerce) en el modelo nuevo")
w("")
w("En el area comprometida el Alerce no existe; dist_alerce deberia ser grande.")
w("")
# de que clase (viejo) provienen los pixeles que el nuevo llama BN01
from_bn01 <- ct[v_new == gv_bn01][order(-count)]
w("Pixeles que el modelo nuevo clasifica BN01, segun su clase en el modelo viejo:")
w("")
w("| era (viejo) | area_ha nuevo=BN01 |")
w("|---|---:|")
for (i in seq_len(min(10, nrow(from_bn01)))) {
  w("| %s | %s |", from_bn01$fuel_old[i], format(round(from_bn01$area_ha[i]), big.mark = "."))
}
w("")

# cruce con dist_alerce
da_path <- "C:/No_nube/modelingFuelsKitral/pisos_vegetacionales/dist_rasters/rm/dist_alerce.tif"
if (file.exists(da_path)) {
  da <- rast(da_path)
  da <- resample(crop(da, r_new), r_new, method = "near")
  bn01_new <- ifel(r_new == gv_bn01, 1L, NA)
  da_vals_bn01 <- values(mask(da, bn01_new))
  da_vals_bn01 <- da_vals_bn01[!is.na(da_vals_bn01)]
  da_all <- values(mask(da, r_new)); da_all <- da_all[!is.na(da_all)]
  w("Distancia al Alerce (km) dentro del area comprometida:")
  w("")
  w("- Todo el area: min %.1f, mediana %.1f, max %.1f",
    min(da_all)/1000, median(da_all)/1000, max(da_all)/1000)
  if (length(da_vals_bn01) > 0) {
    w("- Solo pixeles BN01 (nuevo): min %.1f, mediana %.1f, max %.1f",
      min(da_vals_bn01)/1000, median(da_vals_bn01)/1000, max(da_vals_bn01)/1000)
  }
  w("")
  w("(Si la mediana de dist_alerce en los BN01 no es menor que en el resto,")
  w("la feature de distancia NO esta explicando el error: el modelo predice")
  w("Alerce a distancias grandes igual.)")
  w("")
}

# ---- 5. PCH1: de donde salio la explosion ----
gv_pch1 <- lookup[fuel_type == "PCH1", grid_value]
from_pch1 <- ct[v_new == gv_pch1 & v_old != gv_pch1][order(-count)]
w("## 5. PCH1 (Pastizales Densos): origen de la expansion")
w("")
w("| era (viejo) | area_ha ganada por PCH1 |")
w("|---|---:|")
for (i in seq_len(min(10, nrow(from_pch1)))) {
  w("| %s | %s |", from_pch1$fuel_old[i], format(round(from_pch1$area_ha[i]), big.mark = "."))
}
w("")

close(con)
cat("QC report escrito en", file.path(OUT, "QC_REPORT_modelo_nuevo_vs_viejo_2025.md"), "\n")
