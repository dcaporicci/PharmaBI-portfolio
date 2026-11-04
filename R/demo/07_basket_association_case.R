#===============================================================================
# PharmaBI
#
# Script: 07_basket_association_case.R
# Objective: Compare product-pair frequency, confidence and lift.
# Author: Danilo Caporicci
#===============================================================================

library(dplyr)
library(DBI)
library(RSQLite)
library(here)

# Load the shared path resolver
source(
  here("R", "config", "data_paths.R")
)

# Select synthetic demonstration data
demo_pair_paths <- pharmabi_data_paths("demo")

# Read the existing SQL query as a single text string
demo_pair_sql <- paste(
  readLines(
    here("sql", "13_basket_pair_frequency_by_period.sql"),
    encoding = "UTF-8",
    warn = FALSE
  ),
  collapse = "\n"
)

# Load product-pair indicators for an inclusive date interval
load_demo_pairs <- function(start_date, end_date) {

  connection <- dbConnect(
    SQLite(),
    dbname = demo_pair_paths$database_file,
    flags = SQLITE_RO
  )

  on.exit(
    dbDisconnect(connection),
    add = TRUE
  )

  dbGetQuery(
    connection,
    demo_pair_sql,
    params = list(start_date, end_date)
  )
}

# Load pairs for the complete demonstration sales window
demo_pairs <- load_demo_pairs(
  start_date = "2026-01-05",
  end_date = "2026-09-20"
)

# Rank pairs by lift before applying a frequency threshold
demo_top_lift_unfiltered <- demo_pairs |>
  arrange(
    desc(lift),
    desc(receipts_together),
    product_code_a,
    product_code_b
  ) |>
  slice_head(n = 10)

# Define the minimum co-occurrence count
demo_min_pair_receipts <- 5L

# Keep pairs meeting the frequency threshold
demo_pairs_filtered <- demo_pairs |>
  filter(
    receipts_together >= demo_min_pair_receipts
  )

# Rank the selected pairs by lift
demo_top_lift_filtered <- demo_pairs_filtered |>
  arrange(
    desc(lift),
    desc(receipts_together),
    product_code_a,
    product_code_b
  ) |>
  slice_head(n = 10)

# Compare repeated pairs with the highest-lift unfiltered example
demo_pair_case_comparison <- bind_rows(
  demo_pairs_filtered,
  demo_top_lift_unfiltered |>
    slice_head(n = 1)
) |>
  mutate(
    meets_frequency_threshold =
      receipts_together >= demo_min_pair_receipts
  ) |>
  arrange(
    desc(receipts_together),
    product_code_a,
    product_code_b
  )

# Define the directory for demonstration case outputs
demo_pair_case_dir <- file.path(
  demo_pair_paths$data_root,
  "case_studies"
)

dir.create(
  demo_pair_case_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Export the four-pair comparison without rounding
readr::write_csv(
  demo_pair_case_comparison,
  file.path(
    demo_pair_case_dir,
    "basket_association_comparison.csv"
  )
)
