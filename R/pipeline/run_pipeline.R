#===============================================================================
# PharmaBI
#
# Script: run_pipeline.R
#
# Objective:
# Execute the complete PharmaBI ETL and validation pipeline.
#
# Author:
# Danilo Caporicci
#===============================================================================

library(here)

start_time <- Sys.time()

message("=======================================")
message("        PharmaBI Pipeline")
message("=======================================")

dir.create(here::here("data", "clean"),
           recursive = TRUE,
           showWarnings = FALSE)

dir.create(here::here("data", "dimensions"),
           recursive = TRUE,
           showWarnings = FALSE)

dir.create(here::here("data", "facts"),
           recursive = TRUE,
           showWarnings = FALSE)

source(here("R", "pipeline", "01_import.R"))
source(here("R", "pipeline", "02_data_quality.R"))
source(here("R", "pipeline", "03_data_cleaning.R"))
source(here("R", "pipeline", "04_build_dimensions.R"))
source(here("R", "pipeline", "05_build_fact_sales.R"))
source(here("R", "pipeline", "06_validate_fact_sales.R"))

end_time <- Sys.time()

message(
  "Execution time: ",
  round(
    as.numeric(
      difftime(end_time, start_time, units = "secs")
    ),
    2
  ),
  " seconds"
)

message("=======================================")
message(" Pipeline completed successfully")
message("=======================================")
