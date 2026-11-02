#===============================================================================
# PharmaBI
# Script: 01_build_database.R
# Objective: Build the private SQLite database using the shared builder.
#===============================================================================

source(
  here::here("R", "config", "data_paths.R"),
  local = TRUE
)

source(
  here::here("R", "database", "build_database.R"),
  local = TRUE
)

database_paths <- pharmabi_data_paths("private")

private_database <- build_pharmabi_database(
  paths = database_paths
)

# Preserve the diagnostic names used by the existing workflow
invisible(
  list2env(private_database, envir = environment())
)
