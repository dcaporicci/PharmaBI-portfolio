#===============================================================================
# PharmaBI
# Script: 05_period_comparison_case.R
# Objective: Reproduce the synthetic February-March portfolio example.
# Author: Danilo Caporicci
#
# Run after generating and verifying the demo. Reads the demo RDS only.
# Output CSVs are saved under the Git-ignored data/demo/case_studies/ directory.
#===============================================================================

run_demo_period_case <- function() {

  packages <- c("here", "dplyr", "readr")
  missing <- packages[!vapply(
    packages, requireNamespace, logical(1), quietly = TRUE
  )]
  if (length(missing)) {
    stop("Install required packages: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  source(here::here("R", "config", "data_paths.R"), local = TRUE)
  paths <- pharmabi_data_paths("demo")
  if (!file.exists(paths$fact_file)) {
    stop("Generate and verify the demo before running this example.", call. = FALSE)
  }
  fact <- readRDS(paths$fact_file)

  # Guard against obvious input mix-ups; the demo path is explicitly selected.
  if (!isTRUE(all(
    startsWith(fact$product_code, "D") &
      startsWith(fact$product_desc, "DEMO ")
  ))) {
    stop("Expected synthetic product identifiers and labels.", call. = FALSE)
  }

  periods <- fact |>
    dplyr::filter(
      sale_type == "retail",
      date >= as.Date("2026-02-01"),
      date <= as.Date("2026-03-31")
    ) |>
    dplyr::mutate(period = format(date, "%Y-%m")) |>
    dplyr::group_by(period) |>
    dplyr::summarise(
      active_days = dplyr::n_distinct(date),
      receipts = dplyr::n_distinct(sale_id),
      revenue = sum(revenue),
      profit = sum(profit),
      revenue_per_active_day = revenue / active_days,
      profit_per_active_day = profit / active_days,
      overall_margin = if (revenue != 0) profit / revenue else NA_real_,
      receipts_per_active_day = receipts / active_days,
      average_net_revenue_per_receipt = revenue / receipts,
      .groups = "drop"
    )

  reference <- dplyr::filter(periods, period == "2026-02")
  current <- dplyr::filter(periods, period == "2026-03")
  if (nrow(reference) != 1L || nrow(current) != 1L) {
    stop("Both February and March 2026 must contain retail records.", call. = FALSE)
  }

  metric_columns <- c(
    "active_days", "receipts", "revenue", "profit",
    "revenue_per_active_day", "profit_per_active_day",
    "receipts_per_active_day", "average_net_revenue_per_receipt"
  )
  comparison <- data.frame(
    metric = c(
      "Active days", "Receipts", "Net revenue", "Recorded profit",
      "Net revenue per active day", "Recorded profit per active day",
      "Receipts per active day", "Average net revenue per receipt"
    ),
    reference_value = as.numeric(unlist(reference[metric_columns], use.names = FALSE)),
    current_value = as.numeric(unlist(current[metric_columns], use.names = FALSE))
  )
  comparison$absolute_change <- comparison$current_value - comparison$reference_value
  comparison$percentage_change <- NA_real_
  nonzero <- comparison$reference_value != 0
  comparison$percentage_change[nonzero] <-
    100 * comparison$absolute_change[nonzero] / comparison$reference_value[nonzero]

  margin_change <- data.frame(
    reference_margin = reference$overall_margin,
    current_margin = current$overall_margin,
    change_percentage_points =
      100 * (current$overall_margin - reference$overall_margin)
  )

  output_dir <- file.path(paths$data_root, "case_studies")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(periods, file.path(output_dir, "period_overview.csv"))
  readr::write_csv(comparison, file.path(output_dir, "period_changes.csv"))
  readr::write_csv(margin_change, file.path(output_dir, "period_margin_change.csv"))

  message("Synthetic period comparison prepared successfully.")
  message("Case-study outputs: ", output_dir)

  invisible(list(
    periods = as.data.frame(periods), comparison = comparison,
    margin_change = margin_change, output_dir = output_dir
  ))
}

demo_period_example <- NULL
demo_period_example <- run_demo_period_case()
