#===============================================================================
# PharmaBI
# Objective: Resolve paths for an explicitly selected data mode.
#===============================================================================

pharmabi_data_paths <- function(mode) {

  if (
    !is.character(mode) ||
    length(mode) != 1L ||
    is.na(mode) ||
    !mode %in% c("demo", "private")
  ) {
    stop(
      "Choose data mode explicitly: 'demo' or 'private'.",
      call. = FALSE
    )
  }

  data_root <- if (mode == "demo") {
    here::here("data", "demo")
  } else {
    here::here("data")
  }

  list(
    mode = mode,
    data_root = data_root,
    fact_file = file.path(
      data_root, "facts", "fact_sales.rds"
    ),
    reference_file = file.path(
      data_root, "reference", "atc_reference.rds"
    ),
    database_dir = file.path(
      data_root, "database"
    ),
    database_file = file.path(
      data_root, "database", "pharmabi.sqlite"
    ),
    powerbi_dir = file.path(
      data_root, "powerbi"
    )
  )
}
