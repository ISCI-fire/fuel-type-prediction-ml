# #-----------------------------------------------------------
# # Proyecto: PINC230018 (Desafios 2024) 

# # Ejemplo de como aplicar la funcion con el modelo de random forest ajustado para 
# # predecir la distribución espacial de tipos de combustibles segun kitral usando como predictores variables 
# # de sensores remotos.

# # Se usa la data cuve de la region de biobio como ejemplo

# # Si bien se require de un solo raster (de clase "SpatRaster") donde cada layer es un predictor requierido,
# # el ejemplo muestra como crear dicho raster a partir de los rasters que traen la info por separado

# #-----------------------------------------------------------

#load librariesview?usp=sharing
require(googledrive)
drive_auth() #requires fire2a gmail account
require(parallel)
require(stringr)
require(terra)
require(raster)
require(data.table)
require(readr)
#-----------------------------------------------------------

# Create a temporary directory for terra
dir.create("temp.terra")
terraOptions(
  memfrac = 0,#Use onle x fraction of RAM before using disk
  tempdir = "temp.terra",# temporary directory for terra
  progress = 3         
)
#-----------------------------------------------------------



# #-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# #Downloading data cuve from F2A google drive and prepraing raster stack for model input
# #-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

#Downloading data cuve region del bio bio
# ID of folder in Google Drive
folder_id <- as_id("https://drive.google.com/drive/folders/1JOoBhg3Y01grglIS9TTIJxXH4rSKmroi")#nuble
#as_id("https://drive.google.com/drive/folders/1L2nps9bWAK38A6icc0MeppOVULHcYFUX") # maule
#as_id("https:/</drive.google.com/drive/folders/1rEdZIARjlNRxYLA-zynC--IIcrnWhLA6") #bio bio

# List files in the folder (only files for P3 temporal variables and avoiding evi, temperature and precipitation)
archivos <- drive_ls(path = folder_id)

#Filtring files (variables) to that are predictors in the model
archivos <- archivos[!str_detect(archivos$name, "aux.xml"),]
archivos <- archivos[!str_detect(archivos$name, "climate_variables"),]
# Folder to save downloaded files
dir.create("temp.dc")

# Download files
for (i in seq_len(nrow(archivos))) {
  drive_download(
    file = archivos[i, ],
    path = file.path("temp.dc", archivos$name[i]),
    overwrite = TRUE
  )
}
#-----------------------------------------------------------

#Regions code, it is a dummy variable predictor nedded by the model
#So model works well only for predicting fuel distribution for this regions
codigo_biobio<- 1
codigo_maule <- 2
codigo_nuble <- 3
regionCode<-codigo_nuble

#Making raster stack for bio bio region but only with P3 temporal variables
d2 <- list.files("temp.dc")

#raster stack
out<-list()
for(i in 1:length(d2)){
message(paste("worinkg on raster",i,"of",length(d2)))
d.h<-rast(paste("temp.dc",d2[i],sep="/"))
out[[i]]<-d.h
}
d_biobio<-rast(out)

#Adding layer ass region code
r.h <- d_biobio[[1]] # Usar el primer predictor como plantilla para la extensión/resolución
values(r.h) <- regionCode #need to be for the specific region
names(r.h) <- "region_code" # Predictor name
r.h2 <- terra::mask(x = r.h, mask = d_biobio[[1]])
d_biobio_f <- rast(list(d_biobio, r.h2))

#saving raster
writeRaster(d_biobio_f,"regionDC.tif",overwrite=TRUE)
rm(d_biobio); rm(d2); rm(out); rm(r.h); rm(d_biobio_f)
gc()

#removing temp.dc foler
if (dir.exists("temp.dc")) {
  unlink("temp.dc", recursive = TRUE)
}

#-----------------------------------------------------------


#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#Predicting fuel distribution for region with
#-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
require(terra)

#calling model function
source("fun_KitralFuelModel.r")

#loading raster
r<-rast("regionDC.tif")
names(r)#predictors names, (evi it is not needed)

#Downloading model
  file_id <- "https://drive.google.com/file/d/1YUBZavrAFvGiv7BKk5Q-xU7UZYHokuvT/view?usp=drive_link"
  file <- drive_get(as_id(file_id))
  drive_download(file, overwrite = TRUE, path = file.path(getwd(),file$name))

#model file name
model<- "xgb_model_optimized2_hpeta_0.01max_depth_12min_child_weight_6lambda_1alpha_0subsample_0.7colsample_bytree_0.7gamma_1"#sin elev(0.1 acc)

#predicting with function. Take lote of time to run it but it works
mlKitralFuelModel(model,#XGBoost fitted model name on folder
r, #predictors as spatRaster terra object
file.out.lab="Nuble",#label for raster kitral fuels distribution output file
blockSize=100# block size for processing csv files needed
)