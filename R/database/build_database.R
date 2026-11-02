#===============================================================================
# PharmaBI
#
# Script: build_database.R
# Objective: Build SQLite from explicitly selected input and output paths.
#
# The supplied paths select either private or synthetic demonstration data.
# Sourcing this file defines the function without opening or changing a database.
#
# Author: Danilo Caporicci
#===============================================================================

build_pharmabi_database <- function(paths, sql_dir = here::here("sql")) {

  library(DBI)
  library(RSQLite)
  library(dplyr)

  required_paths <- c(
    "mode", "fact_file", "reference_file",
    "database_dir", "database_file"
  )

  if (!is.list(paths) || !all(required_paths %in% names(paths))) {
    stop("Supply paths from pharmabi_data_paths().", call. = FALSE)
  }

  if (!identical(paths$mode, "demo") && !identical(paths$mode, "private")) {
    stop("Choose data mode explicitly: 'demo' or 'private'.", call. = FALSE)
  }

  input_files <- c(paths$fact_file, paths$reference_file)
  missing_inputs <- input_files[!file.exists(input_files)]

  if (length(missing_inputs) > 0L) {
    stop(
      "Missing inputs for mode '", paths$mode, "': ",
      paste(missing_inputs, collapse = ", "),
      call. = FALSE
    )
  }

  required_sql <- c(
    "01_sales_by_type.sql", "02_retail_overview.sql",
    "03_retail_monthly.sql", "04_create_retail_view.sql",
    "05_products_minimum_volume.sql"
  )

  missing_sql <- required_sql[
    !file.exists(file.path(sql_dir, required_sql))
  ]

  if (length(missing_sql) > 0L) {
    stop(
      "Missing SQL files: ", paste(missing_sql, collapse = ", "),
      call. = FALSE
    )
  }

  message("Building SQLite database for data mode: ", paths$mode)
  message("Database: ", paths$database_file)

  # Prepare the database directory
  database_dir <- paths$database_dir

  dir.create(
    database_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  database_file <- paths$database_file

  # Load the validated sales fact table
  fact_sales <- readRDS(paths$fact_file)

  # Prepare dates for SQLite storage
  fact_sales_sql <- fact_sales |>
    mutate(
      date = format(date, "%Y-%m-%d")
    )

  # Build product labels using the latest observed description
  dim_products_sql <- fact_sales |>
    group_by(product_code) |>
    summarise(
      product_desc = product_desc[which.max(date)],
      .groups = "drop"
    )

  # Validate product identifiers and labels
  stopifnot(
    !anyNA(dim_products_sql),
    anyDuplicated(dim_products_sql$product_code) == 0L
  )

  # Define complete calendar years covering the source data
  calendar_start <- as.Date(
    paste0(format(min(fact_sales$date), "%Y"), "-01-01")
  )

  calendar_end <- as.Date(
    paste0(format(max(fact_sales$date), "%Y"), "-12-31")
  )

  # Build the date dimension for SQLite
  dim_date_sql <- tibble(
    date = seq.Date(
      from = calendar_start,
      to = calendar_end,
      by = "day"
    )
  ) |>
    mutate(
      year = as.integer(format(date, "%Y")),
      month_number = as.integer(format(date, "%m")),
      year_month = format(date, "%Y-%m"),
      weekday_number = as.integer(format(date, "%u")),
      date = format(date, "%Y-%m-%d")
    )

  # Validate the date dimension and sales date coverage
  stopifnot(
    !anyNA(dim_date_sql),
    anyDuplicated(dim_date_sql$date) == 0L,
    all(
      format(fact_sales$date, "%Y-%m-%d") %in%
        dim_date_sql$date
    )
  )

  # Load the validated ATC reference

  atc_reference_file <- paths$reference_file

  if (!file.exists(atc_reference_file)) {
    stop(
      paste(
        "ATC reference not found.",
        "Prepare the reference for the selected data mode first."
      )
    )
  }

  atc_reference <- readRDS(atc_reference_file)

  # Prepare official ATC level 2 labels

  dim_atc_level2_sql <- atc_reference |>
    filter(atc_level == 2L) |>
    transmute(
      atc_level2 = atc_code,
      atc_level2_desc = atc_desc
    )

  # Validate category identifiers and descriptions

  stopifnot(
    nrow(dim_atc_level2_sql) > 0L,
    !anyNA(dim_atc_level2_sql),
    anyDuplicated(dim_atc_level2_sql$atc_level2) == 0L
  )

  # Open the database, creating the file if it does not exist
  database_connection <- dbConnect(
    SQLite(),
    dbname = database_file
  )

  # Release the connection even when a query or validation fails
  on.exit(
    {
      if (dbIsValid(database_connection)) {
        dbDisconnect(database_connection)
      }
    },
    add = TRUE
  )

  # Remove the previous view before rebuilding the database table
  dbExecute(
    database_connection,
    "DROP VIEW IF EXISTS vw_retail_sales;"
  )

  # Write the sales fact table to SQLite
  dbWriteTable(
    conn = database_connection,
    name = "fact_sales",
    value = fact_sales_sql,
    overwrite = TRUE,
    row.names = FALSE
  )

  # Write the product dimension to SQLite
  dbWriteTable(
    conn = database_connection,
    name = "dim_products",
    value = dim_products_sql,
    overwrite = TRUE,
    row.names = FALSE
  )

  # Write the date dimension to SQLite
  dbWriteTable(
    conn = database_connection,
    name = "dim_date",
    value = dim_date_sql,
    overwrite = TRUE,
    row.names = FALSE
  )

  # Write ATC level 2 labels to SQLite

  dbWriteTable(
    conn = database_connection,
    name = "dim_atc_level2",
    value = dim_atc_level2_sql,
    overwrite = TRUE,
    row.names = FALSE
  )

  # Read and create the retail sales view
  retail_view_query <- paste(
    readLines(
      file.path(sql_dir, "04_create_retail_view.sql"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  dbExecute(
    database_connection,
    retail_view_query
  )

  # Inspect the available tables
  database_tables <- dbListTables(database_connection)

  # Check the number of rows stored in SQLite
  database_row_count <- dbGetQuery(
    database_connection,
    "
    SELECT COUNT(*) AS rows
    FROM fact_sales;
    "
  )

  # Read the SQL query from its source file
  sales_by_type_query <- paste(
    readLines(
      file.path(sql_dir, "01_sales_by_type.sql"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  # Execute the query in SQLite
  database_sales_by_type <- dbGetQuery(
    database_connection,
    sales_by_type_query
  )

  # Read and execute the retail overview query
  retail_overview_query <- paste(
    readLines(
      file.path(sql_dir, "02_retail_overview.sql"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  database_retail_overview <- dbGetQuery(
    database_connection,
    retail_overview_query
  )

  # Read and execute the monthly retail query
  retail_monthly_query <- paste(
    readLines(
      file.path(sql_dir, "03_retail_monthly.sql"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  database_retail_monthly <- dbGetQuery(
    database_connection,
    retail_monthly_query
  )

  # Read and execute the product performance query
  products_query <- paste(
    readLines(
      file.path(sql_dir, "05_products_minimum_volume.sql"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )

  database_top_products <- dbGetQuery(
    database_connection,
    products_query
  )

  # Calculate the expected totals directly in R
  expected_sales_by_type <- fact_sales |>
    group_by(sale_type) |>
    summarise(
      sales_rows = n(),
      transactions = n_distinct(sale_id),
      packages_sold = sum(packages),
      revenue = sum(revenue),
      costs = sum(costs),
      profit = sum(profit),
      .groups = "drop"
    ) |>
    arrange(sale_type)

  # Validate SQLite results against the R source data
  stopifnot(
    database_row_count$rows == nrow(fact_sales),
    isTRUE(
      all.equal(
        database_sales_by_type,
        expected_sales_by_type,
        check.attributes = FALSE,
        tolerance = 1e-10
      )
    )
  )

  # Calculate the expected monthly results in R
  expected_retail_monthly <- fact_sales |>
    filter(sale_type == "retail") |>
    mutate(month = format(date, "%Y-%m")) |>
    group_by(month) |>
    summarise(
      active_days = n_distinct(date),
      receipts = n_distinct(sale_id),
      revenue = sum(revenue),
      profit = sum(profit),
      revenue_per_day = revenue / active_days,
      profit_per_day = profit / active_days,
      .groups = "drop"
    ) |>
    arrange(month)

  # Validate monthly SQLite results against R
  stopifnot(
    isTRUE(
      all.equal(
        database_retail_monthly,
        expected_retail_monthly,
        check.attributes = FALSE,
        tolerance = 1e-10
      )
    )
  )

  message("SQLite database built and sales totals validated successfully.")

  invisible(list(
    data_mode = paths$mode,
    database_dir = database_dir,
    database_file = database_file,
    fact_sales = fact_sales,
    fact_sales_sql = fact_sales_sql,
    dim_products_sql = dim_products_sql,
    calendar_start = calendar_start,
    calendar_end = calendar_end,
    dim_date_sql = dim_date_sql,
    atc_reference_file = atc_reference_file,
    atc_reference = atc_reference,
    dim_atc_level2_sql = dim_atc_level2_sql,
    retail_view_query = retail_view_query,
    database_tables = database_tables,
    database_row_count = database_row_count,
    sales_by_type_query = sales_by_type_query,
    database_sales_by_type = database_sales_by_type,
    retail_overview_query = retail_overview_query,
    database_retail_overview = database_retail_overview,
    retail_monthly_query = retail_monthly_query,
    database_retail_monthly = database_retail_monthly,
    products_query = products_query,
    database_top_products = database_top_products,
    expected_sales_by_type = expected_sales_by_type,
    expected_retail_monthly = expected_retail_monthly
  ))
}
