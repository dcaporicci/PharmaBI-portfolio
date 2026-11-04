#===============================================================================
# PharmaBI
#
# Script: 06_product_performance_case.R
# Objective: Compare product sales volume, recorded profit and overall margin.
# Author: Danilo Caporicci
#===============================================================================

library(dplyr)
library(here)

# Load the shared path resolver
source(
  here("R", "config", "data_paths.R")
)

# Explicitly select synthetic demonstration data
demo_product_paths <- pharmabi_data_paths("demo")

# Load retail sales
demo_product_sales <- readRDS(
  demo_product_paths$fact_file
) |>
  filter(sale_type == "retail")

# Aggregate retail sales at product level
demo_product_performance <- demo_product_sales |>
  group_by(product_code) |>
  summarise(
    product_desc = product_desc[which.max(date)],
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    .groups = "drop"
  )

# Calculate product margin and flag zero recorded costs
demo_product_performance <- demo_product_performance |>
  mutate(
    overall_margin = if_else(
      revenue != 0,
      profit / revenue,
      NA_real_
    ),
    zero_cost_flag = costs == 0
  )

# Calculate economic indicators per net package
demo_product_performance <- demo_product_performance |>
  mutate(
    average_net_revenue_per_package = if_else(
      packages_sold > 0,
      revenue / packages_sold,
      NA_real_
    ),
    profit_per_package = if_else(
      packages_sold > 0,
      profit / packages_sold,
      NA_real_
    )
  )

# Rank products by total recorded profit
demo_top_profit <- demo_product_performance |>
  arrange(
    desc(profit),
    product_code
  ) |>
  slice_head(n = 10)

# Rank products by net packages sold
demo_top_packages <- demo_product_performance |>
  arrange(
    desc(packages_sold),
    product_code
  ) |>
  slice_head(n = 10)

# Define the minimum net volume for the margin comparison
demo_min_packages <- 10L

# Rank eligible products by overall margin
demo_top_margin <- demo_product_performance |>
  filter(
    packages_sold >= demo_min_packages,
    revenue > 0,
    !zero_cost_flag
  ) |>
  arrange(
    desc(overall_margin),
    product_code
  ) |>
  slice_head(n = 10)

# Extract the leading product code from each ranking
demo_case_product_codes <- c(
  demo_top_packages$product_code[1],
  demo_top_profit$product_code[1],
  demo_top_margin$product_code[1]
)

# Prepare the comparison used in the portfolio example
demo_product_case_comparison <- demo_product_performance |>
  filter(product_code %in% demo_case_product_codes) |>
  select(
    product_code,
    product_desc,
    packages_sold,
    revenue,
    profit,
    overall_margin,
    average_net_revenue_per_package,
    profit_per_package
  ) |>
  arrange(desc(profit), product_code)

# Define the directory for demonstration case outputs
demo_product_case_dir <- file.path(
  demo_product_paths$data_root,
  "case_studies"
)

# Create the directory when needed
dir.create(
  demo_product_case_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Export the comparison without rounding numeric values
readr::write_csv(
  demo_product_case_comparison,
  file.path(
    demo_product_case_dir,
    "product_performance_comparison.csv"
  )
)