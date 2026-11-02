#===============================================================================
# PharmaBI
# Script: export_powerbi.R
# Objective: Export SQLite tables to explicitly selected Power BI CSV paths.
#
# The database is opened read-only. All validations precede CSV writes.
# Sourcing this file defines the function without reading or exporting data.
#===============================================================================

export_pharmabi_powerbi <- function(paths) {

  library(DBI)
  library(RSQLite)
  library(readr)

  required_paths <- c("mode", "database_file", "powerbi_dir")

  if (!is.list(paths) || !all(required_paths %in% names(paths))) {
    stop("Supply paths from pharmabi_data_paths().", call. = FALSE)
  }

  if (!identical(paths$mode, "demo") && !identical(paths$mode, "private")) {
    stop("Choose data mode explicitly: 'demo' or 'private'.", call. = FALSE)
  }

  message("Exporting Power BI tables for data mode: ", paths$mode)
  message("CSV directory: ", paths$powerbi_dir)

  # Locate the existing database
  database_file <- paths$database_file

  if (!file.exists(database_file)) {
    builder_file <- if (paths$mode == "demo") {
      "R/demo/02_build_demo_database.R"
    } else {
      "R/database/01_build_database.R"
    }

    stop(
      "Database not found for mode '", paths$mode,
      "'. Run ", builder_file, " first.",
      call. = FALSE
    )
  }

  # Read the tables using a read-only connection
  connection <- dbConnect(
    SQLite(),
    dbname = database_file,
    flags = SQLITE_RO
  )

  powerbi_tables <- tryCatch(
    {
      list(
        fact_sales_retail = dbGetQuery(
          connection,
          paste(
            "SELECT *",
            "FROM vw_retail_sales",
            "ORDER BY date, sale_id, product_code;"
          )
        ),
        dim_date = dbGetQuery(
          connection,
          "SELECT * FROM dim_date ORDER BY date;"
        ),

        dim_products = dbGetQuery(
          connection,
          paste(
            "SELECT product_code, product_desc",
            "FROM dim_products",
            "ORDER BY product_code;"
          )
        ),

        dim_atc_level2 = dbGetQuery(
          connection,
          paste(
            "SELECT atc_level2, atc_level2_desc",
            "FROM dim_atc_level2",
            "ORDER BY atc_level2;"
          )
        )
      )
    },
    finally = {
      dbDisconnect(connection)
    }
  )

  # Validate product identifiers, descriptions and retail coverage
  stopifnot(
    is.character(powerbi_tables$dim_products$product_code),

    !anyNA(powerbi_tables$dim_products),

    anyDuplicated(
      powerbi_tables$dim_products$product_code
    ) == 0L,

    all(
      powerbi_tables$fact_sales_retail$product_code %in%
        powerbi_tables$dim_products$product_code
    )
  )

  # Validate ATC level 2 reference labels
  stopifnot(
    nrow(powerbi_tables$dim_atc_level2) > 0L,

    is.character(
      powerbi_tables$dim_atc_level2$atc_level2
    ),

    !anyNA(powerbi_tables$dim_atc_level2),

    anyDuplicated(
      powerbi_tables$dim_atc_level2$atc_level2
    ) == 0L,

    all(
      nchar(powerbi_tables$dim_atc_level2$atc_level2) == 3L
    )
  )

  # Validate retail scope before writing any CSV files
  stopifnot(
    nrow(powerbi_tables$fact_sales_retail) > 0L,
    !anyNA(powerbi_tables$fact_sales_retail$sale_type),
    all(powerbi_tables$fact_sales_retail$sale_type == "retail")
  )

  # Catch accidental use of operational records in the demo export
  if (paths$mode == "demo") {
    demo_identifiers_valid <- isTRUE(all(
      startsWith(powerbi_tables$fact_sales_retail$sale_id, "DEMO|") &
        startsWith(powerbi_tables$fact_sales_retail$product_code, "D") &
        startsWith(powerbi_tables$fact_sales_retail$product_desc, "DEMO ")
    ))

    demo_dimension_valid <- isTRUE(all(
      startsWith(powerbi_tables$dim_products$product_code, "D") &
        startsWith(powerbi_tables$dim_products$product_desc, "DEMO ")
    ))

    if (!demo_identifiers_valid || !demo_dimension_valid) {
      stop(
        "Demo export refused: expected synthetic identifiers and labels.",
        call. = FALSE
      )
    }
  }

  # Create the local export directory
  export_dir <- paths$powerbi_dir

  dir.create(
    export_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # Export without rounding numeric values
  write_csv(
    powerbi_tables$fact_sales_retail,
    file.path(export_dir, "fact_sales_retail.csv"),
    na = ""
  )

  write_csv(
    powerbi_tables$dim_date,
    file.path(export_dir, "dim_date.csv"),
    na = ""
  )

  write_csv(
    powerbi_tables$dim_products,
    file.path(export_dir, "dim_products.csv"),
    na = ""
  )

  write_csv(
    powerbi_tables$dim_atc_level2,
    file.path(export_dir, "dim_atc_level2.csv"),
    na = ""
  )

  message(
    "Retail sales rows exported: ",
    nrow(powerbi_tables$fact_sales_retail)
  )

  message(
    "Calendar rows exported: ",
    nrow(powerbi_tables$dim_date)
  )

  message(
    "Product dimension rows exported: ",
    nrow(powerbi_tables$dim_products)
  )

  message(
    "ATC level 2 reference rows exported: ",
    nrow(powerbi_tables$dim_atc_level2)
  )

  exported_files <- setNames(
    file.path(export_dir, paste0(names(powerbi_tables), ".csv")),
    names(powerbi_tables)
  )

  invisible(list(
    data_mode = paths$mode,
    export_dir = export_dir,
    files = exported_files,
    tables = powerbi_tables
  ))
}
