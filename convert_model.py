import xgboost as xgb

model_old = "C:/No_nube/fuel-type-prediction-ml/xgb_model_optimized2_hpeta_0.01max_depth_12min_child_weight_6lambda_1alpha_0subsample_0.7colsample_bytree_0.7gamma_1"
model_new = model_old + ".json"

booster = xgb.Booster()
booster.load_model(model_old)
booster.save_model(model_new)

print(f"Modelo convertido exitosamente a: {model_new}")
