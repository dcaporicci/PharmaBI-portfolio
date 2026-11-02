#===============================================================================
# PharmaBI
# Script: 01_export_powerbi.R
# Objective: Export private SQLite tables for Power BI using the shared exporter.
#===============================================================================

source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

source(
  here::here("R", "export", "export_powerbi.R"),
  local = TRUE
)

powerbi_paths <- pharmabi_data_paths("private")

private_powerbi_export <- export_pharmabi_powerbi(
  paths = powerbi_paths
)

# Preserve the table and path objects used by the existing workflow
powerbi_tables <- private_powerbi_export$tables
database_file <- powerbi_paths$database_file
export_dir <- private_powerbi_export$export_dir
