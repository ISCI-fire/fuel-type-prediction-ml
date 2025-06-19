# Kitral Fuel Model Prediction Workflow (PINC230018 Project)

This document outlines the process for predicting fuel type distribution using the scripts `run_example.r` and `fun_KitralFuelModel.r`. The `run_example.r` script serves as a driver that prepares the necessary data and then invokes the core prediction function contained within `fun_KitralFuelModel.r`.

## `run_example.r`: Example Execution Script

This script provides a working example of how to use the complete prediction pipeline. Its workflow is divided into two distinct parts: data preparation and model execution.

### Part 1: Creating Predictor Data

This section demonstrates how to build the required input `SpatRaster` object from the "data cuve" files for a specific region.

* **Setup**: It begins by loading necessary R packages such as `googledrive` and `terra`, and authenticating a Google account. It also configures `terra` options to manage memory by using a temporary directory on disk.
* **Data Download**: The script downloads remote sensing data from a specified Google Drive folder. It filters the file list to exclude auxiliary (`aux.xml`) and climate-related files that are not used as predictors. The files are saved into a temporary folder named `temp.dc`.
* **Raster Stack Creation**:
    * The individual raster files downloaded to the `temp.dc` folder are loaded and combined into a single `SpatRaster` object.
    * A critical step is the creation and addition of a `region_code` layer to the stack. This is a dummy variable predictor required by the model to distinguish between regions (e.g., Biobío, Maule, or Ñuble).
* **Save and Cleanup**: The final multi-layer raster, containing all predictors, is saved as `regionDC.tif`. The temporary `temp.dc` folder is then removed.

### Part 2: Predicting Fuel Distribution

After preparing the input data, this section calls the prediction function.

* **Load Function and Model**:
    * The core prediction function is loaded into the R environment by executing the `fun_KitralFuelModel.r` script via the `source()` command.
    * The `SpatRaster` created in the previous part (`regionDC.tif`) is loaded.
    * The pre-trained XGBoost model is downloaded from a specified Google Drive link.
* **Execute Prediction**: The script calls the `mlKitralFuelModel` function with four key arguments:
    1.  `model`: The filename of the trained XGBoost model.
    2.  `predictors`: The `SpatRaster` object containing the predictor variables.
    3.  `file.out.lab`: A text label used to name the final output raster file (e.g., "Nuble").
    4.  `blockSize`: A number defining how many raster rows to process at a time, which helps manage memory usage.

---

## `fun_KitralFuelModel.r`: The Core Prediction Function

This file defines the `mlKitralFuelModel` function, which is engineered to predict fuel types over large geographic areas by processing raster data in manageable chunks.

### Key Steps and Logic

1.  **Verifications and Setup**:
    * **Input Validation**: The function starts by performing several checks. It ensures that the `predictors` argument is provided and is of class `SpatRaster`. It also verifies that all required predictor names are present as layers in the input raster; otherwise, it stops and lists the missing variables.
    * **Dependency Checks**: It confirms that a required lookup table (`kitral_lookup_table-modified.csv`) exists in the working directory. It also checks if all necessary packages like `xgboost`, `terra`, and `data.table` are installed.
    * **Temporary Folders**: It creates temporary directories (`temp.csv`, `temp.terra`, `temp.r`) to store intermediate files generated during the process.

2.  **Data Processing in Chunks**:
    * To avoid memory overload, the function reads the input `predictors` raster not all at once, but in smaller, horizontal blocks. The size of these blocks is determined by the `blockSize` parameter.
    * For each block, it reads the pixel values and coordinates, removes rows with `NA` values, and writes the resulting data frame to a numbered CSV file in the `temp.csv` folder.

3.  **Prediction Loop**:
    * The function loads the pre-trained model specified by the `model` argument using `xgb.load()`.
    * It then iterates through each of the temporary CSV files. For each chunk of data:
        * It reads the CSV file into a data frame.
        * It performs one-hot encoding on the `region_code` column by creating new dummy variable columns (`region_code.1`, `region_code.2`, `region_code.3`).
        * The predictor data is converted into an `xgb.DMatrix` object, which is the required format for the `xgboost` package.
        * The model predicts probabilities for each pixel, resulting in a matrix with 32 columns representing the different fuel classes.
        * The predicted class for each pixel is determined by finding the class with the highest probability using `max.col`.
        * The numeric class predictions are then mapped to final grid values using the `kitral_lookup_table-modified.csv` file.
        * A new temporary `SpatRaster` is created for the chunk, populated with the predicted grid values, and saved as a `.tif` file in the `temp.r` folder.

4.  **Final Assembly and Cleanup**:
    * Once all chunks have been predicted, the function loops through the temporary raster files in the `temp.r` folder and merges them into a single, complete raster using a mosaic operation.
    * This final, combined raster map is saved to the disk. The output filename is based on the `file.out.lab` parameter (e.g., `KitralFuelsDistribution_Nuble.tif`).
    * Finally, the function removes all temporary folders and their contents to clean up the workspace.