#===============================================================================
# PharmaBI
# Script: 03_export_demo_powerbi.R
# Objective: Export synthetic demonstration tables to data/demo/powerbi/.
#===============================================================================

source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

source(
  here::here("R", "export", "export_powerbi.R"),
  local = TRUE
)

demo_paths <- pharmabi_data_paths("demo")

demo_powerbi_export <- export_pharmabi_powerbi(
  paths = demo_paths
)

message("Synthetic Power BI CSV exports ready.")
