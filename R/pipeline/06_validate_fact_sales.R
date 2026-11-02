#===============================================================================
# PharmaBI
#
# Script: 06_validate_fact_sales.R
# Objective: Validate private fact_sales as the final step of the ETL pipeline.
#
# The shared validator also supports synthetic data through an explicit path.
# Existing diagnostic objects remain available in the sourcing environment.
#
# Author: Danilo Caporicci
#===============================================================================

source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

source(
  here::here("R", "validation", "validate_fact_sales.R"),
  local = TRUE
)

validation_paths <- pharmabi_data_paths("private")

message("Validating private fact_sales.")

private_validation <- validate_fact_sales(
  fact_file = validation_paths$fact_file
)

# Preserve the diagnostic names used by the existing workflow
invisible(
  list2env(private_validation, envir = environment())
)
