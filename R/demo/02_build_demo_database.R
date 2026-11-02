#===============================================================================
# PharmaBI
# Script: 02_build_demo_database.R
# Objective: Validate synthetic data and build the separate demo SQLite database.
#===============================================================================

source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

source(
  here::here("R", "validation", "validate_fact_sales.R"),
  local = TRUE
)

source(
  here::here("R", "database", "build_database.R"),
  local = TRUE
)

demo_paths <- pharmabi_data_paths("demo")

message("Validating synthetic demonstration data.")

demo_validation <- validate_fact_sales(
  fact_file = demo_paths$fact_file
)

demo_database <- build_pharmabi_database(
  paths = demo_paths
)

message("Synthetic demonstration database ready.")
