mlKitralFuelModel<-function(model=NULL,predictors=NULL,
file.out.lab=NULL,
blockSize=NULL,
id.fuel=NULL){

#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#Doing verifications
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

#cheeking predictor condition
if(is.null(predictors)==TRUE){stop("predictors are required")}

if(class(predictors)[1]!="SpatRaster"){stop("predictors must be of class SpatRaster")}

if(is.null(file.out.lab)==TRUE){filename.out="KitralFuelsDistribution_out.tif"}else {
   filename.out<-paste0("KitralFuelsDistribution_",file.out.lab,".tif")}

# NOTA (Fase 4.1): 'vars' (predictores, en el orden exacto) y las etiquetas de
# clase ya NO se hardcodean. Se derivan del propio modelo (feature_names embebidos
# en el .json) y de id_fuel.csv más abajo, tras cargar el modelo — elimina la
# fuente histórica de bugs de orden. La validación de que el raster de entrada
# contenga todos los predictores también se hace ahí.

# id_fuel.csv: por defecto junto al modelo (../ respecto a la carpeta xgb_fuels_model/)
if(is.null(id.fuel)) id.fuel <- file.path(dirname(dirname(model)), "id_fuel.csv")
if(!file.exists(id.fuel)) stop("id_fuel.csv not found: ", id.fuel, " (pass it via id.fuel=)")

#ckecking if there is a lookup table
if(!file.exists("kitral_lookup_table-modified.csv")){stop("Kitral lookup table not found, please put a file named 'kitral_lookup_table-modified.csv' in working directory")} 
 
#cheeking libraries condition
if(!require(data.table)){stop("data.table package is required, please install it")}else{
require(data.table)}

if(!require(readr)){stop("readr package is required, please install it")}else{
require(readr)}

if(!require(terra)){stop("terra package is required, please install it")}else{
  require(terra)}

if(!require(raster)){stop("raster package is required, please install it")}else{
  require(raster)}

if(!require(parallel)){stop("parallel package is required, please install it")}else{
  require(parallel)}

if(!require(stringr)){stop("stringr package is required, please install it")}else{
  require(stringr)}

if(!require(reticulate)){stop("reticulate package is required, please install it")}else{
  require(reticulate)}
#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# Cargar modelo y DERIVAR vars + etiquetas de clase (Fase 4.1)
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
message("Loading model")
model_abs <- if (file.exists(model)) normalizePath(model, winslash = "/") else file.path(getwd(), model)
if (!reticulate::py_available()) reticulate::use_condaenv("xgb_convert", required = TRUE)
xgb_py         <- reticulate::import("xgboost")
np             <- reticulate::import("numpy")
imported_model <- xgb_py$Booster()
imported_model$load_model(model_abs)

# vars = predictores en el ORDEN EXACTO del modelo (feature_names embebidos).
# No hardcodear: el .json de xgboost 3.x guarda los nombres de la DMatrix de
# entrenamiento. as.character por si reticulate devuelve una lista de Python.
vars <- as.character(imported_model$feature_names)
if (length(vars) == 0 || all(is.na(vars))) {
  stop("El modelo no tiene feature_names embebidos; no se puede derivar 'vars'. ",
       "Reentrenar guardando la DMatrix con nombres de columna.")
}
message("Predictores derivados del modelo: ", length(vars))

# Validar que el raster de predictores contenga todas las variables del modelo
faltan <- vars[!vars %in% names(predictors)]
if (length(faltan) > 0) {
  stop("Faltan predictores en el raster de entrada: ", paste(faltan, collapse = ", "))
}

# Etiquetas de clase desde id_fuel.csv: la clase 0-based k -> idf$fuel[k+1]
# (el índice de clase de xgboost sigue el orden de filas de id_fuel.csv, que es
# el orden de niveles usado en el entrenamiento).
idf           <- read.csv(id.fuel, stringsAsFactors = FALSE)
labels_kitral <- as.character(idf$fuel)
n_classes     <- length(labels_kitral)
message("Clases derivadas de id_fuel.csv: ", n_classes)
#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#Doing temporal folders
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# folds for temporal files
fold.name <- "temp.csv"
if (!dir.exists(fold.name)) {
dir.create(fold.name)}

# Create a temporary directory for terra
fold.name.t <- "temp.terra"
if (!dir.exists(fold.name.t)) {
dir.create(fold.name.t)}

fold.name.r <- "temp.r"
if (!dir.exists(fold.name.r)) {
dir.create(fold.name.r)}
#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# Transform raster to data.frame by chunks
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# Saving raster properties
nrows.r = nrow(predictors)
ncols.r = ncol(predictors)
extent.r = ext(predictors)
crs.r = crs(predictors)

# Define block size and number of chunks
block_size <- blockSize  # Adjust based on memory
num_chunks <- ceiling(nrows.r / block_size) # Número total de fragmentos

readStart(predictors)

#Preparing data for predictions
for(i in 1:num_chunks){
     message(paste("Preparing data for predictions in chunks. ","Chunk", i, "of", num_chunks))
     start_row <- (i - 1) * block_size + 1
     end_row <- min(start_row + block_size - 1, nrows.r)
     nrows_block <- end_row - start_row + 1

     # Read values
     valores <- terra::readValues(predictors, start_row, nrows_block, 1, ncol(predictors), TRUE)
    
     # Get cell coordinates
     celdas <- unlist(raster::cellFromRow(predictors, start_row:end_row))
     coords <- xyFromCell(predictors, celdas)

     # Create data.frame and write
     df <- data.frame(coords, valores)%>%na.omit()

     write.csv(df,paste(fold.name,"/",i,sep=""),row.names=FALSE)

}
rm(predictors)
rm(df)
rm(celdas)
rm(coords)
rm(valores)
#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# Doing predictions with XGBOOST 
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

# (modelo ya cargado arriba: imported_model, xgb_py, np, vars, labels_kitral, n_classes)
files.h<-list.files(path=fold.name)
for(i in 1:length(files.h)){
porcentaje_progreso <- round((i / length(files.h)) * 100, 1)
 message(paste("Predicting chunk", i, "of", length(files.h)))
d.h<-fread(paste(fold.name,"/",files.h[i],sep=""))%>%as.data.frame

#predictors as matrix
m1<-as.matrix(d.h[,vars])
colnames(m1)

# Predict via Python (bypasses R readBin >2GB limit)
m1_np   <- np$array(m1, dtype = "float32")
dm      <- xgb_py$DMatrix(data = m1_np, feature_names = vars)
py_pred <- imported_model$predict(dm)
# Python returns (n_samples, 32) matrix; flatten row-major to match original flat-vector format
pred <- if (is.matrix(py_pred)) c(t(py_pred)) else as.vector(py_pred)

#Convertir el vector plano en una matriz (filas: observaciones, columnas: clases)
pred_xgb_matrix <- matrix(pred, ncol = n_classes, byrow = TRUE)

#Obtener clase predicha como la de mayor probabilidad
pred_xgb_numeric <- max.col(pred_xgb_matrix) - 1  # Las clases empiezan en 0 en XGBoost

# Convertir a factor con niveles y etiquetas derivadas de id_fuel.csv
# (índice de clase 0-based k -> labels_kitral[k+1])
predict <- factor(pred_xgb_numeric, levels = 0:(n_classes - 1),
                  labels = labels_kitral)

pred.h<-as.data.frame(predict)

pred.h$id<-1:nrow(pred.h)

#Estos pasos es para que el valor de la clase corresponda a lo que reconoce C2F+W
kitral_keys<-read.csv("kitral_lookup_table-modified.csv")
names(kitral_keys)[4]<-"predict"
pred3<-merge(pred.h,kitral_keys[,c(4,1)],by="predict",all.x=TRUE) 
pred3<-pred3[order(pred3$id),]

r.h <- rast(nrows = nrows.r,
                     ncols = ncols.r,
                     extent = extent.r,
                     crs = crs.r)

values(r.h) <- NA

cell_indices <- cellFromXY(r.h, d.h[,c("x", "y")])

values(r.h)[cell_indices] <- pred3[, "grid_value"]

terra::writeRaster(r.h, paste(fold.name.r,"/",i,".tif",sep=""), overwrite = TRUE)

#free memory
rm(pred.h); rm(pred3); rm(r.h); rm(pred_xgb_matrix); rm(pred_xgb_numeric); rm(d.h); rm(m1); rm(m1_np); rm(dm); rm(py_pred)
gc()

message(paste(porcentaje_progreso, "% completed"))
}
#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# Doing final mosaic
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

files.h<-list.files(path=fold.name.r)
#mosaic raster
for(j in 1:length(files.h)){
message(paste("Doing final mosaic. Worinkg on raster",j,"of",length(files.h)))
d.h<-rast(paste("temp.r/",files.h[j],sep=""))
if(j==1){r.out<-d.h}else{r.out<-mosaic(r.out,d.h, fun = "sum")}}

#save raster
message("Saving raster with final mosaic")
writeRaster(r.out,filename = filename.out,overwrite = TRUE)

message("Removing temporal files and folders")

#Deleting temp.r folder
if (dir.exists(fold.name.r)) {
  unlink(fold.name.r, recursive = TRUE)
}
#Deleting temp.csv folder
if (dir.exists(fold.name)) {
  unlink(fold.name, recursive = TRUE)
}
#Deleting temp.terra folder
if (dir.exists(fold.name.t)) {
  unlink(fold.name.t, recursive = TRUE)
}

message("Done! The output raster is saved as ", filename.out)
#-----------------------------------------------------------
}