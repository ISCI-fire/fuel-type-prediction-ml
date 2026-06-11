import xgboost as xgb

model_json = "C:/No_nube/fuel-type-prediction-ml/xgb_model_optimized2_hpeta_0.01max_depth_12min_child_weight_6lambda_1alpha_0subsample_0.7colsample_bytree_0.7gamma_1.json"
model_ubj  = model_json.replace(".json", ".ubj")

booster = xgb.Booster()
booster.load_model(model_json)
booster.save_model(model_ubj)

print(f"Convertido a UBSON: {model_ubj}")
