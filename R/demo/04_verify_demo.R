#===============================================================================
# PharmaBI
# Script: 04_verify_demo.R
# Objective: Verify the documented synthetic fixture across R, SQLite and CSVs.
# Author: Danilo Caporicci
#
# Run after demo scripts 01, 02 and 03. Only demo paths are selected.
# The database is read-only. Reports are written under data/demo/validation/.
# This checks data outputs; browser interactions and Power BI DAX remain manual.
#===============================================================================

verify_pharmabi_demo <- function() {

  packages <- c("here", "dplyr", "DBI", "RSQLite", "readr")
  missing_packages <- packages[!vapply(
    packages, requireNamespace, logical(1), quietly = TRUE
  )]

  if (length(missing_packages) > 0L) {
    stop(
      "Install required packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  source(here::here("R", "config", "data_paths.R"), local = TRUE)
  source(
    here::here("R", "validation", "validate_fact_sales.R"),
    local = TRUE
  )

  paths <- pharmabi_data_paths("demo")
  validation_root <- file.path(paths$data_root, "validation")
  dir.create(validation_root, recursive = TRUE, showWarnings = FALSE)
  report_dir <- tempfile(
    pattern = paste0("run-", format(Sys.time(), "%Y%m%d-%H%M%S"), "-"),
    tmpdir = validation_root
  )
  dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  message("Verifying synthetic demonstration data.")
  message("Run reports: ", report_dir)

  checks <- data.frame(
    check = character(), status = character(), detail = character()
  )
  completed <- FALSE
  connection <- NULL
  started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

  # Save the outcome even if a check or query fails. Each run has its own folder;
  # an older successful report is not presented as the result of a failed run.
  on.exit({
    if (!is.null(connection) && DBI::dbIsValid(connection)) {
      DBI::dbDisconnect(connection)
    }
    final_status <- data.frame(
      check = "Run status",
      status = if (completed) "Passed" else "Failed",
      detail = if (completed) "All checks completed" else "Run did not complete"
    )
    utils::write.csv(
      rbind(checks, final_status),
      file.path(report_dir, "verification_summary.csv"),
      row.names = FALSE, fileEncoding = "UTF-8"
    )
    writeLines(
      c(
        paste("Verification started:", started_at),
        paste("Run completed:", completed),
        paste("RNG configuration during verification:",
              paste(RNGkind(), collapse = "; ")),
        "This records the verification session, not the generation session.",
        "", utils::capture.output(utils::sessionInfo())
      ),
      file.path(report_dir, "verification_session.txt"),
      useBytes = TRUE
    )
  }, add = TRUE)

  check <- function(label, condition, detail = "") {
    passed <- isTRUE(condition)
    checks <<- rbind(checks, data.frame(
      check = label,
      status = if (passed) "Passed" else "Failed",
      detail = detail
    ))
    if (!passed) {
      stop("Demo check failed: ", label, ". ", detail, call. = FALSE)
    }
  }

  # Absolute tolerance, deliberately much smaller than a stored 0.001 EUR unit.
  same_values <- function(actual, expected, tolerance = 1e-7) {
    if (length(actual) != length(expected)) return(FALSE)
    if (length(actual) == 0L) return(TRUE)
    if (!identical(is.na(actual), is.na(expected))) return(FALSE)
    keep <- !is.na(actual)
    if (is.numeric(actual) && is.numeric(expected)) {
      return(all(is.finite(actual[keep])) &&
               all(is.finite(expected[keep])) &&
               all(abs(actual[keep] - expected[keep]) <= tolerance))
    }
    identical(
      enc2utf8(as.character(actual[keep])),
      enc2utf8(as.character(expected[keep]))
    )
  }

  check_table <- function(label, actual, expected, keys = character()) {
    actual <- as.data.frame(actual)
    expected <- as.data.frame(expected)
    same_shape <- identical(names(actual), names(expected)) &&
      nrow(actual) == nrow(expected)
    if (!same_shape) {
      check(label, FALSE, "Different column names or row counts")
    }
    if (length(keys) > 0L && nrow(actual) > 0L) {
      actual <- actual[do.call(order, actual[keys]), , drop = FALSE]
      expected <- expected[do.call(order, expected[keys]), , drop = FALSE]
    }
    bad <- names(actual)[!vapply(
      names(actual),
      function(column) same_values(actual[[column]], expected[[column]]),
      logical(1)
    )]
    check(
      label, length(bad) == 0L,
      if (length(bad)) paste("Different columns:", paste(bad, collapse = ", "))
      else paste(nrow(actual), "rows reconciled; absolute tolerance 1e-7")
    )
  }

  sql_query <- function(filename, params = NULL) {
    sql <- paste(readLines(
      here::here("sql", filename), encoding = "UTF-8", warn = FALSE
    ), collapse = "\n")
    if (is.null(params)) DBI::dbGetQuery(connection, sql)
    else DBI::dbGetQuery(connection, sql, params = params)
  }

  csv_names <- c(
    "fact_sales_retail", "dim_date", "dim_products", "dim_atc_level2"
  )
  csv_files <- file.path(paths$powerbi_dir, paste0(csv_names, ".csv"))
  input_files <- c(paths$fact_file, paths$reference_file,
                   paths$database_file, csv_files)
  check("Required demo inputs", all(file.exists(input_files)),
        "Generate, build and export demo data with scripts 01, 02 and 03 first")
  input_md5_before <- tools::md5sum(input_files)

  validation <- validate_fact_sales(paths$fact_file)
  check("Shared fact validation", all(validation$validation_summary$status == "Passed"),
        "All checks in validate_fact_sales() passed")
  fact <- validation$fact_sales

  check(
    "Synthetic identifier and label guard",
    all(startsWith(fact$product_code, "D")) &&
      all(startsWith(fact$product_desc, "DEMO ")) &&
      all(startsWith(fact$manufacturer_code, "DM")) &&
      all(startsWith(fact$manufacturer_desc, "Demo manufacturer ")) &&
      all(startsWith(fact$sale_id, "DEMO|") |
            startsWith(fact$sale_id, "DEMO-NONRETAIL|")),
    "Prefix guard for accidental input mix-ups; not an anonymity guarantee"
  )

  baseline_r <- fact |>
    dplyr::group_by(sale_type) |>
    dplyr::summarise(
      sales_rows = dplyr::n(), transactions = dplyr::n_distinct(sale_id),
      packages_sold = sum(packages), revenue = sum(revenue),
      costs = sum(costs), profit = sum(profit), .groups = "drop"
    )
  baseline_documented <- data.frame(
    sale_type = c("non_retail", "retail"), sales_rows = c(18L, 7817L),
    transactions = c(3L, 4800L), packages_sold = c(291L, 9607L),
    revenue = c(5606.562, 185853.967), costs = c(3745.954, 118563.536),
    profit = c(1860.608, 67290.431)
  )
  check_table("Documented demo baseline", baseline_r,
              baseline_documented, "sale_type")

  retail <- dplyr::filter(fact, sale_type == "retail")
  check("Documented retail coverage",
        identical(as.character(range(retail$date)),
                  c("2026-01-05", "2026-09-20")))
  check("Documented retail product count",
        dplyr::n_distinct(retail$product_code) == 240L)

  connection <- DBI::dbConnect(
    RSQLite::SQLite(), dbname = paths$database_file, flags = RSQLite::SQLITE_RO
  )
  fact_sql <- DBI::dbGetQuery(
    connection, "SELECT * FROM fact_sales ORDER BY date, sale_id, product_code;"
  )
  fact_expected <- dplyr::mutate(fact, date = format(date, "%Y-%m-%d"))
  check_table("SQLite fact against source RDS", fact_sql,
              fact_expected, c("sale_id", "product_code"))
  check_table("SQL sales-by-type totals", sql_query("01_sales_by_type.sql"),
              baseline_r, "sale_type")

  monthly_r <- retail |>
    dplyr::mutate(month = format(date, "%Y-%m")) |>
    dplyr::group_by(month) |>
    dplyr::summarise(
      active_days = dplyr::n_distinct(date),
      receipts = dplyr::n_distinct(sale_id), revenue = sum(revenue),
      profit = sum(profit), revenue_per_day = revenue / active_days,
      profit_per_day = profit / active_days, .groups = "drop"
    )
  check_table("SQL monthly totals and daily averages",
              sql_query("03_retail_monthly.sql"), monthly_r, "month")

  product_labels <- fact |>
    dplyr::group_by(product_code) |>
    dplyr::summarise(product_desc = product_desc[which.max(date)], .groups = "drop")
  check_table(
    "Product dimension against source RDS",
    DBI::dbGetQuery(connection,
                    "SELECT product_code, product_desc FROM dim_products;"),
    product_labels, "product_code"
  )
  calendar_dates <- seq.Date(as.Date("2026-01-01"), as.Date("2026-12-31"), by = "day")
  calendar_r <- data.frame(
    date = format(calendar_dates, "%Y-%m-%d"),
    year = as.integer(format(calendar_dates, "%Y")),
    month_number = as.integer(format(calendar_dates, "%m")),
    year_month = format(calendar_dates, "%Y-%m"),
    weekday_number = as.integer(format(calendar_dates, "%u"))
  )
  check_table("Full 2026 calendar dimension",
              DBI::dbGetQuery(connection, "SELECT * FROM dim_date;"), calendar_r, "date")
  atc_r <- readRDS(paths$reference_file) |>
    dplyr::filter(atc_level == 2L) |>
    dplyr::transmute(atc_level2 = atc_code, atc_level2_desc = atc_desc)
  check_table("ATC dimension against public reference",
              DBI::dbGetQuery(connection, "SELECT * FROM dim_atc_level2;"),
              atc_r, "atc_level2")

  # Enumerate unordered pairs independently in R using combinations per receipt.
  # Returns remain product presences, matching the documented basket definition.
  expected_pairs <- function(rows) {
    products <- dplyr::distinct(rows, sale_id, product_code)
    total <- dplyr::n_distinct(products$sale_id)
    frequency <- dplyr::count(products, product_code, name = "receipts")
    pair_rows <- lapply(
      unname(split(products$product_code, products$sale_id)),
      function(codes) {
        if (length(codes) < 2L) return(NULL)

        combinations <- utils::combn(sort(codes), 2L)

        data.frame(
          product_code_a = combinations[1L, ],
          product_code_b = combinations[2L, ]
        )
      }
    )

    pairs <- dplyr::bind_rows(
      c(
        list(data.frame(
          product_code_a = character(),
          product_code_b = character()
        )),
        pair_rows
      )
    ) |>
      dplyr::count(
        product_code_a,
        product_code_b,
        name = "receipts_together"
      )
    # A typed empty result also tests the no-pair and no-sales query branches.
    if (nrow(pairs) == 0L) {
      return(data.frame(
        product_code_a = character(), product_desc_a = character(),
        product_code_b = character(), product_desc_b = character(),
        receipts_together = integer(), receipts_a = integer(), receipts_b = integer(),
        confidence_a_to_b = numeric(), confidence_b_to_a = numeric(),
        support = numeric(), expected_receipts_together = numeric(), lift = numeric()
      ))
    }
    a <- frequency$receipts[match(pairs$product_code_a, frequency$product_code)]
    b <- frequency$receipts[match(pairs$product_code_b, frequency$product_code)]
    together <- pairs$receipts_together
    data.frame(
      product_code_a = pairs$product_code_a,
      product_desc_a = product_labels$product_desc[
        match(pairs$product_code_a, product_labels$product_code)],
      product_code_b = pairs$product_code_b,
      product_desc_b = product_labels$product_desc[
        match(pairs$product_code_b, product_labels$product_code)],
      receipts_together = together, receipts_a = a, receipts_b = b,
      confidence_a_to_b = together / a, confidence_b_to_a = together / b,
      support = together / total, expected_receipts_together = (a / total) * b,
      lift = (together / total) / ((a / total) * (b / total))
    )
  }

  periods <- list(
    full = c("2026-01-05", "2026-09-20"),
    february = c("2026-02-01", "2026-02-28"),
    march = c("2026-03-01", "2026-03-31"),
    partial_months = c("2026-01-15", "2026-02-10"),
    single_day = c("2026-01-05", "2026-01-05"),
    closed_days = c("2026-04-12", "2026-04-13"),
    outside_coverage = c("2026-10-01", "2026-10-31")
  )
  full_pairs <- NULL
  for (period_name in names(periods)) {
    interval <- periods[[period_name]]
    rows <- dplyr::filter(retail,
                          date >= as.Date(interval[1L]),
                          date <= as.Date(interval[2L]))
    active_days <- dplyr::n_distinct(rows$date)
    has_sales <- nrow(rows) > 0L
    revenue <- if (has_sales) sum(rows$revenue) else NA_real_
    profit <- if (has_sales) sum(rows$profit) else NA_real_
    overview_r <- data.frame(
      active_days = active_days, receipts = dplyr::n_distinct(rows$sale_id),
      revenue = revenue, profit = profit,
      overall_margin = if (has_sales && revenue != 0) profit / revenue else NA_real_,
      revenue_per_active_day = if (has_sales) revenue / active_days else NA_real_,
      profit_per_active_day = if (has_sales) profit / active_days else NA_real_
    )
    params <- as.list(interval)
    check_table(paste("Period overview:", period_name),
                sql_query("06_retail_overview_by_period.sql", params), overview_r)
    monthly_period_r <- rows |>
      dplyr::mutate(month = format(date, "%Y-%m")) |>
      dplyr::group_by(month) |>
      dplyr::summarise(
        active_days = dplyr::n_distinct(date), revenue = sum(revenue),
        revenue_per_day = revenue / active_days, .groups = "drop"
      )
    check_table(paste("Period monthly data:", period_name),
                sql_query("07_retail_monthly_by_period.sql", params),
                monthly_period_r, "month")
    receipts_r <- rows |>
      dplyr::group_by(sale_id, date) |>
      dplyr::summarise(
        unique_products = dplyr::n_distinct(product_code),
        packages_sold = sum(packages), revenue = sum(revenue),
        costs = sum(costs), profit = sum(profit), .groups = "drop"
      ) |>
      dplyr::mutate(date = format(date, "%Y-%m-%d"))
    check_table(paste("Receipt baskets:", period_name),
                sql_query("12_basket_receipts_by_period.sql", params),
                receipts_r, "sale_id")
    pairs_sql <- sql_query("13_basket_pair_frequency_by_period.sql", params)
    check_table(paste("Pairs, support, confidence and lift:", period_name),
                pairs_sql, expected_pairs(rows), c("product_code_a", "product_code_b"))
    check(paste("Total pair occurrences:", period_name),
          same_values(sum(pairs_sql$receipts_together),
                      sum(choose(receipts_r$unique_products, 2L))),
          "Pair occurrences equal the sum of k*(k-1)/2 over receipt baskets")
    if (period_name == "full") full_pairs <- pairs_sql
  }

  # Parse identifiers as text. Convert only the numeric columns defined by SQLite.
  # Compare the actual exported values, rather than recomputing another export.
  database_queries <- c(
    fact_sales_retail = "SELECT * FROM vw_retail_sales ORDER BY date, sale_id, product_code;",
    dim_date = "SELECT * FROM dim_date ORDER BY date;",
    dim_products = "SELECT product_code, product_desc FROM dim_products ORDER BY product_code;",
    dim_atc_level2 = "SELECT atc_level2, atc_level2_desc FROM dim_atc_level2 ORDER BY atc_level2;"
  )
  export_counts <- integer(length(csv_names))
  names(export_counts) <- csv_names
  for (table_name in csv_names) {
    expected <- DBI::dbGetQuery(connection, database_queries[[table_name]])
    if (table_name == "fact_sales_retail") {
      check_table("Retail view against source RDS", expected,
                  dplyr::mutate(retail, date = format(date, "%Y-%m-%d")),
                  c("sale_id", "product_code"))
    }
    actual <- readr::read_csv(
      file.path(paths$powerbi_dir, paste0(table_name, ".csv")),
      col_types = readr::cols(.default = readr::col_character()),
      na = "", name_repair = "minimal", show_col_types = FALSE,
      progress = FALSE
    )
    check(paste("CSV parse:", table_name), nrow(readr::problems(actual)) == 0L)
    check(paste("CSV columns:", table_name), identical(names(actual), names(expected)))
    for (column in names(expected)[vapply(expected, is.numeric, logical(1))]) {
      parsed <- readr::parse_double(
        actual[[column]], na = "", locale = readr::locale(decimal_mark = ".")
      )
      check(paste("CSV numeric parse:", table_name, column),
            nrow(readr::problems(parsed)) == 0L)
      actual[[column]] <- parsed
    }
    check_table(paste("Power BI CSV values:", table_name), actual, expected)
    export_counts[table_name] <- nrow(actual)
  }

  DBI::dbDisconnect(connection)
  connection <- NULL
  check("Demo inputs unchanged by verification",
        identical(input_md5_before, tools::md5sum(input_files)),
        "RDS, SQLite and four CSV fingerprints unchanged")

  fingerprints <- data.frame(
    artifact = c("demo_fact", "demo_atc_reference", "demo_database", csv_names),
    md5 = unname(input_md5_before)
  )
  utils::write.csv(fingerprints, file.path(report_dir, "input_fingerprints.csv"),
                   row.names = FALSE)
  versions <- data.frame(
    package = c(packages, "shiny", "bslib"),
    version = vapply(c(packages, "shiny", "bslib"), function(package) {
      if (requireNamespace(package, quietly = TRUE)) {
        as.character(utils::packageVersion(package))
      } else NA_character_
    }, character(1))
  )
  utils::write.csv(versions, file.path(report_dir, "package_versions.csv"),
                   row.names = FALSE)
  utils::write.csv(utils::head(full_pairs, 20L),
                   file.path(report_dir, "top_demo_pairs.csv"),
                   row.names = FALSE, fileEncoding = "UTF-8")

  completed <- TRUE
  message("Synthetic demo verification completed successfully.")
  message("Verification reports: ", report_dir)

  invisible(list(
    summary = checks, baseline = as.data.frame(baseline_r),
    pair_summary = data.frame(
      distinct_pairs = nrow(full_pairs),
      pair_occurrences = sum(full_pairs$receipts_together),
      pairs_seen_once = sum(full_pairs$receipts_together == 1L),
      most_frequent_pair_receipts = if (nrow(full_pairs)) {
        max(full_pairs$receipts_together)
      } else 0L
    ),
    top_pairs = utils::head(full_pairs, 20L), export_counts = export_counts,
    report_dir = report_dir
  ))
}

# Clear the previous result before running, including when a new run fails.
demo_checks <- NULL
demo_checks <- verify_pharmabi_demo()
