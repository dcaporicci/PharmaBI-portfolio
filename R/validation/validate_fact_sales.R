#===============================================================================
# PharmaBI
#
# Script: validate_fact_sales.R
# Objective: Validate a fact table supplied through an explicit RDS file path.
#
# Returns a named list containing the fact table, validation summaries and audits.
# This file defines the function; sourcing it does not load any dataset.
#
# Author: Danilo Caporicci
#===============================================================================

validate_fact_sales <- function(fact_file) {

  library(dplyr)

  if (
    !is.character(fact_file) ||
      length(fact_file) != 1L ||
      is.na(fact_file) ||
      !nzchar(trimws(fact_file))
  ) {
    stop("Provide one explicit RDS file path.", call. = FALSE)
  }

  if (!file.exists(fact_file)) {
    stop("Fact table not found: ", fact_file, call. = FALSE)
  }

  fact_sales <- readRDS(fact_file)

  message("fact_sales successfully loaded.")

  # Check that the input is a non-empty data frame
  stopifnot(
    is.data.frame(fact_sales),
    nrow(fact_sales) > 0L
  )

  # Additional columns are allowed; required columns must exist
  required_columns <- c(
    "date",
    "time_slot_quarter", "time_slot_half", "time_slot_hour",
    "sale_id", "number_sales",
    "manufacturer_code", "manufacturer_desc",
    "product_code", "product_desc",
    "gm_code", "gm_desc",
    "atc_code", "atc_desc",
    "revenue", "costs", "profit", "margin",
    "packages", "sale_type"
  )

  missing_columns <- setdiff(
    required_columns,
    names(fact_sales)
  )

  if (length(missing_columns) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  message("Required columns and non-empty input validated.")

  #===============================================================================
  # 1. Structural validation
  #===============================================================================

  message("Running structural validation...")

  glimpse(fact_sales)

  fact_dimensions <- tibble(
    rows = nrow(fact_sales),
    columns = ncol(fact_sales)
  )

  fact_dimensions


  #-------------------------------------------------------------------------------
  # Column type validation
  #-------------------------------------------------------------------------------

  stopifnot(
    inherits(fact_sales$date, "Date"),
    is.character(fact_sales$sale_id),
    is.character(fact_sales$manufacturer_code),
    is.character(fact_sales$product_code),
    is.character(fact_sales$gm_code),
    is.character(fact_sales$atc_code),
    is.integer(fact_sales$number_sales),
    is.integer(fact_sales$packages),
    is.numeric(fact_sales$revenue),
    is.numeric(fact_sales$costs),
    is.numeric(fact_sales$profit),
    is.numeric(fact_sales$margin)
  )

  message("Column types validated.")


  #===============================================================================
  # 2. Missing-value validation
  #===============================================================================

  message("Checking missing values...")

  missing_values_summary <- tibble(
    column = names(fact_sales),
    missing_values = colSums(is.na(fact_sales))
  ) %>%
    arrange(desc(missing_values))

  missing_values_summary


  #-------------------------------------------------------------------------------
  # Mandatory fields must not contain NA
  #-------------------------------------------------------------------------------

  stopifnot(
    !any(is.na(fact_sales$date)),
    !any(is.na(fact_sales$sale_id)),
    !any(is.na(fact_sales$product_code)),
    !any(is.na(fact_sales$product_desc)),
    !any(is.na(fact_sales$gm_code)),
    !any(is.na(fact_sales$gm_desc)),
    !any(is.na(fact_sales$revenue)),
    !any(is.na(fact_sales$costs)),
    !any(is.na(fact_sales$profit)),
    !any(is.na(fact_sales$margin)),
    !any(is.na(fact_sales$packages))
  )

  message("Mandatory fields contain no missing values.")

  #-------------------------------------------------------------------------------
  # Mandatory text fields must contain meaningful values
  #-------------------------------------------------------------------------------

  mandatory_text_fields <- c(
    "sale_id",
    "product_code", "product_desc",
    "gm_code", "gm_desc",
    "sale_type"
  )

  stopifnot(
    all(vapply(
      fact_sales[mandatory_text_fields],
      is.character,
      logical(1)
    ))
  )

  blank_text_summary <- tibble(
    field = mandatory_text_fields,
    invalid_rows = vapply(
      fact_sales[mandatory_text_fields],
      function(values) {
        sum(is.na(values) | trimws(values) == "")
      },
      numeric(1)
    )
  )

  stopifnot(all(blank_text_summary$invalid_rows == 0))

  message("Mandatory text fields contain no blank values.")

  #-------------------------------------------------------------------------------
  # Financial values must be finite
  #-------------------------------------------------------------------------------

  financial_fields <- c(
    "revenue", "costs", "profit", "margin"
  )

  non_finite_financial_summary <- tibble(
    field = financial_fields,
    invalid_rows = vapply(
      fact_sales[financial_fields],
      function(values) {
        sum(!is.finite(values))
      },
      numeric(1)
    )
  )

  stopifnot(
    all(non_finite_financial_summary$invalid_rows == 0)
  )

  message("Financial values are finite.")


  #-------------------------------------------------------------------------------
  # ATC missing values are expected for non-medicinal products
  #-------------------------------------------------------------------------------

  atc_missing_summary <- fact_sales %>%
    summarise(
      rows_with_atc = sum(!is.na(atc_code)),
      rows_without_atc = sum(is.na(atc_code)),
      products_with_atc = n_distinct(
        product_code[!is.na(atc_code)]
      ),
      products_without_atc = n_distinct(
        product_code[is.na(atc_code)]
      )
    )

  atc_missing_summary

  inconsistent_atc_rows <- fact_sales %>%
    filter(
      xor(
        is.na(atc_code),
        is.na(atc_desc)
      )
    )

  inconsistent_atc_rows

  stopifnot(nrow(inconsistent_atc_rows) == 0)

  message("ATC code and description are consistently populated.")

  #-------------------------------------------------------------------------------
  # Sale classification and receipt consistency
  #-------------------------------------------------------------------------------

  allowed_sale_types <- c("retail", "non_retail")

  stopifnot(
    is.character(fact_sales$sale_type),
    !anyNA(fact_sales$sale_type),
    all(fact_sales$sale_type %in% allowed_sale_types)
  )

  # Each receipt must belong to one date and one sale type
  inconsistent_receipt_metadata <- fact_sales |>
    group_by(sale_id) |>
    summarise(
      dates = n_distinct(date),
      sale_types = n_distinct(sale_type),
      .groups = "drop"
    ) |>
    filter(
      dates != 1L |
        sale_types != 1L
    )

  stopifnot(
    nrow(inconsistent_receipt_metadata) == 0L
  )

  message("Sale types and receipt metadata validated.")

  #===============================================================================
  # 3. Logical-key validation
  #===============================================================================

  message("Checking logical-key uniqueness...")

  duplicate_keys <- fact_sales %>%
    count(
      sale_id,
      product_code,
      name = "rows_per_key"
    ) %>%
    filter(rows_per_key > 1)

  duplicate_keys

  stopifnot(nrow(duplicate_keys) == 0)

  message("Logical key sale_id + product_code is unique.")


  #===============================================================================
  # 4. Quantity validation
  #===============================================================================

  message("Checking count variables...")

  # number_sales must be a non-missing integer
  invalid_number_sales <- fact_sales %>%
    filter(
      is.na(number_sales) |
        number_sales != floor(number_sales)
    )

  # packages must be a non-missing integer
  invalid_packages_type <- fact_sales %>%
    filter(
      is.na(packages) |
        packages != floor(packages)
    )

  invalid_number_sales
  invalid_packages_type

  stopifnot(
    nrow(invalid_number_sales) == 0,
    nrow(invalid_packages_type) == 0
  )

  message("number_sales and packages have valid integer values.")

  #-------------------------------------------------------------------------------
  # Zero or negative package quantities
  #-------------------------------------------------------------------------------

  non_positive_packages <- fact_sales %>%
    filter(packages <= 0)

  non_positive_packages %>%
    select(
      date,
      sale_id,
      product_code,
      product_desc,
      revenue,
      costs,
      profit,
      margin,
      packages
    )

  message(
    "Rows with zero or negative packages: ",
    nrow(non_positive_packages)
  )

  #===============================================================================
  # 5. Financial consistency
  #===============================================================================

  message("Checking financial consistency...")

  # Validate the formula:
  # profit = revenue - costs

  financial_validation <- fact_sales %>%
    summarise(
      max_profit_difference = max(
        abs(revenue - costs - profit),
        na.rm = TRUE
      ),
      minimum_margin = min(
        margin,
        na.rm = TRUE
      ),
      maximum_margin = max(
        margin,
        na.rm = TRUE
      )
    )

  financial_validation


  #-------------------------------------------------------------------------------
  # Margin formula validation
  #-------------------------------------------------------------------------------

  # Rows with revenue equal to zero are excluded because
  # profit / revenue is undefined.

  margin_validation <- fact_sales %>%
    filter(revenue != 0) %>%
    summarise(
      max_margin_difference = max(
        abs(margin - profit / revenue),
        na.rm = TRUE
      )
    )

  margin_validation


  financial_tolerance <- 1e-10

  stopifnot(
    financial_validation$max_profit_difference < financial_tolerance,
    margin_validation$max_margin_difference < financial_tolerance
  )

  message("Financial formulas validated.")

  #-------------------------------------------------------------------------------
  # Zero-revenue validation
  #-------------------------------------------------------------------------------

  zero_revenue_rows <- fact_sales %>%
    filter(revenue == 0)

  zero_revenue_rows

  message(
    "Rows with zero revenue: ",
    nrow(zero_revenue_rows)
  )

  #===============================================================================
  # 6. Margin-range audit
  #===============================================================================

  message("Auditing negative and out-of-range margins...")

  margin_range_summary <- fact_sales %>%
    summarise(
      negative_margins = sum(
        margin < 0,
        na.rm = TRUE
      ),
      margins_equal_to_one = sum(
        margin == 1,
        na.rm = TRUE
      ),
      margins_above_one = sum(
        margin > 1,
        na.rm = TRUE
      )
    )

  margin_range_summary


  #-------------------------------------------------------------------------------
  # Rows with negative or greater-than-one margins
  #-------------------------------------------------------------------------------

  unusual_margin_rows <- fact_sales %>%
    filter(
      margin < 0 |
        margin > 1
    ) %>%
    select(
      date,
      sale_id,
      product_code,
      product_desc,
      manufacturer_desc,
      revenue,
      costs,
      profit,
      margin,
      packages
    ) %>%
    arrange(margin)

  unusual_margin_rows


  #===============================================================================
  # 7. Negative-margin audit
  #===============================================================================

  message("Building negative-margin audit...")

  negative_margin_audit <- fact_sales %>%
    filter(margin < 0) %>%
    mutate(
      margin_severity = case_when(
        margin < -1    ~ "Extreme",
        margin < -0.20 ~ "High",
        margin < -0.05 ~ "Moderate",
        TRUE           ~ "Low"
      ),
      margin_severity = factor(
        margin_severity,
        levels = c("Extreme", "High", "Moderate", "Low"),
        ordered = TRUE
      )
    )

  #-------------------------------------------------------------------------------
  # Severity distribution
  #-------------------------------------------------------------------------------

  negative_margin_severity <- negative_margin_audit %>%
    count(margin_severity, name = "sales_lines")

  negative_margin_severity


  #-------------------------------------------------------------------------------
  # Economic impact of negative-margin lines
  #-------------------------------------------------------------------------------

  negative_margin_summary <- negative_margin_audit %>%
    summarise(
      sales_lines = n(),
      products = n_distinct(product_code),
      manufacturers = n_distinct(manufacturer_desc),
      receipts = n_distinct(sale_id),
      packages = sum(
        packages,
        na.rm = TRUE
      ),
      revenue = sum(
        revenue,
        na.rm = TRUE
      ),
      costs = sum(
        costs,
        na.rm = TRUE
      ),
      total_loss = sum(
        profit,
        na.rm = TRUE
      ),
      minimum_margin = min(
        margin,
        na.rm = TRUE
      ),
      average_margin = mean(
        margin,
        na.rm = TRUE
      )
    )

  negative_margin_summary


  #-------------------------------------------------------------------------------
  # Most extreme negative-margin rows
  #-------------------------------------------------------------------------------

  extreme_negative_margins <- negative_margin_audit %>%
    filter(margin < -1) %>%
    select(
      date,
      sale_id,
      product_code,
      product_desc,
      manufacturer_desc,
      revenue,
      costs,
      profit,
      margin,
      packages
    ) %>%
    arrange(margin)

  extreme_negative_margins


  #===============================================================================
  # 8. Receipt-level validation
  #===============================================================================

  message("Building receipt-level validation...")

  receipt_summary <- fact_sales %>%
    group_by(
      sale_id,
      date
    ) %>%
    summarise(
      receipt_revenue = sum(
        revenue,
        na.rm = TRUE
      ),
      receipt_costs = sum(
        costs,
        na.rm = TRUE
      ),
      receipt_profit = sum(
        profit,
        na.rm = TRUE
      ),
      receipt_lines = n(),
      receipt_packages = sum(
        packages,
        na.rm = TRUE
      ),
      negative_lines = sum(
        margin < 0,
        na.rm = TRUE
      ),
      has_negative_line = any(
        margin < 0,
        na.rm = TRUE
      ),
      .groups = "drop"
    ) %>%
    mutate(
      receipt_margin = if_else(
        receipt_revenue != 0,
        receipt_profit / receipt_revenue,
        NA_real_
      )
    )


  #-------------------------------------------------------------------------------
  # General receipt summary
  #-------------------------------------------------------------------------------

  receipt_validation <- receipt_summary %>%
    summarise(
      total_receipts = n(),
      receipts_with_negative_lines = sum(
        has_negative_line
      ),
      unprofitable_receipts = sum(
        receipt_profit < 0
      ),
      unprofitable_receipt_share =
        unprofitable_receipts / total_receipts,
      total_receipt_losses =
        -sum(
          receipt_profit[receipt_profit < 0],
          na.rm = TRUE
        ),
      minimum_receipt_margin = min(
        receipt_margin,
        na.rm = TRUE
      )
    )

  receipt_validation


  #-------------------------------------------------------------------------------
  # Receipts containing at least one negative-margin line
  #-------------------------------------------------------------------------------

  negative_receipts <- receipt_summary %>%
    filter(has_negative_line) %>%
    arrange(receipt_margin)

  negative_receipts


  #-------------------------------------------------------------------------------
  # Receipts that are unprofitable overall
  #-------------------------------------------------------------------------------

  unprofitable_receipts <- receipt_summary %>%
    filter(receipt_profit < 0) %>%
    arrange(receipt_margin)

  unprofitable_receipts


  #-------------------------------------------------------------------------------
  # Unprofitable receipts without negative-margin lines
  #-------------------------------------------------------------------------------

  unprofitable_without_negative_lines <- receipt_summary %>%
    filter(
      receipt_profit < 0,
      !has_negative_line
    ) %>%
    arrange(receipt_margin)

  unprofitable_without_negative_lines


  #===============================================================================
  # 9. Overall economic impact
  #===============================================================================

  message("Calculating overall economic impact...")

  overall_financial_summary <- fact_sales %>%
    summarise(
      total_revenue = sum(
        revenue,
        na.rm = TRUE
      ),
      total_costs = sum(
        costs,
        na.rm = TRUE
      ),
      total_profit = sum(
        profit,
        na.rm = TRUE
      ),
      total_packages = sum(
        packages,
        na.rm = TRUE
      )
    ) %>%
    mutate(
      unprofitable_receipt_losses =
        receipt_validation$total_receipt_losses,
      loss_share_of_total_profit =
        unprofitable_receipt_losses / total_profit
    )

  overall_financial_summary


  #===============================================================================
  # 10. Final validation summary
  #===============================================================================

  validation_summary <- tibble(
    validation = c(
      "Column types",
      "Mandatory missing values",
      "Logical-key uniqueness",
      "Count-variable integrity",
      "Profit formula",
      "Margin formula",
      "GM classification coverage"
    ),
    status = rep("Passed", 7),
    observed_value = c(
      "Expected types confirmed",
      "0 missing mandatory values",
      paste(nrow(duplicate_keys), "duplicate keys"),
      "0 invalid count values",
      format(financial_validation$max_profit_difference, scientific = TRUE),
      format(margin_validation$max_margin_difference, scientific = TRUE),
      "0 missing GM classifications"
    )
  )

  # Include the additional structural and consistency checks
  validation_summary <- bind_rows(
    validation_summary,
    tibble(
      validation = c(
        "Non-empty input",
        "Required columns",
        "Mandatory text values",
        "Finite financial values",
        "ATC code-description consistency",
        "Sale type values",
        "Receipt metadata consistency"
      ),
      status = "Passed",
      observed_value = c(
        paste(nrow(fact_sales), "rows"),
        paste(length(missing_columns), "missing columns"),
        paste(
          sum(blank_text_summary$invalid_rows),
          "blank or missing text values"
        ),
        paste(
          sum(non_finite_financial_summary$invalid_rows),
          "non-finite values"
        ),
        paste(nrow(inconsistent_atc_rows), "inconsistent rows"),
        "All rows have an allowed sale type",
        paste(
          nrow(inconsistent_receipt_metadata),
          "inconsistent receipts"
        )
      )
    )
  )

  print(validation_summary, n = Inf, width = Inf)

  message("fact_sales validation completed successfully.")

  # Return the existing diagnostics without modifying the caller environment
  invisible(list(
    fact_sales = fact_sales,
    required_columns = required_columns,
    missing_columns = missing_columns,
    fact_dimensions = fact_dimensions,
    missing_values_summary = missing_values_summary,
    mandatory_text_fields = mandatory_text_fields,
    blank_text_summary = blank_text_summary,
    financial_fields = financial_fields,
    non_finite_financial_summary = non_finite_financial_summary,
    atc_missing_summary = atc_missing_summary,
    inconsistent_atc_rows = inconsistent_atc_rows,
    allowed_sale_types = allowed_sale_types,
    inconsistent_receipt_metadata = inconsistent_receipt_metadata,
    duplicate_keys = duplicate_keys,
    invalid_number_sales = invalid_number_sales,
    invalid_packages_type = invalid_packages_type,
    non_positive_packages = non_positive_packages,
    financial_validation = financial_validation,
    margin_validation = margin_validation,
    financial_tolerance = financial_tolerance,
    zero_revenue_rows = zero_revenue_rows,
    margin_range_summary = margin_range_summary,
    unusual_margin_rows = unusual_margin_rows,
    negative_margin_audit = negative_margin_audit,
    negative_margin_severity = negative_margin_severity,
    negative_margin_summary = negative_margin_summary,
    extreme_negative_margins = extreme_negative_margins,
    receipt_summary = receipt_summary,
    receipt_validation = receipt_validation,
    negative_receipts = negative_receipts,
    unprofitable_receipts = unprofitable_receipts,
    unprofitable_without_negative_lines = unprofitable_without_negative_lines,
    overall_financial_summary = overall_financial_summary,
    validation_summary = validation_summary
  ))
}
