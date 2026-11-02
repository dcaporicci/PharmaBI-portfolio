#===============================================================================
# PharmaBI
#
# Script: 04_atc_analysis.R
#
# Obiettivo:
# Analyze ATC category performance and observed therapeutic demand
#
# Autore:
# Danilo Caporicci
#===============================================================================


#------------------------------------------------------------------------------
# Packages
#------------------------------------------------------------------------------

library(dplyr)
library(here)

fact_sales <- readRDS(
  here("data", "facts", "fact_sales.rds")
)

atc_reference <- readRDS(
  here("data", "reference", "atc_reference.rds")
)

atc_level2_labels <- atc_reference |>
  filter(atc_level == 2L) |>
  transmute(
    atc_level2 = atc_code,
    atc_level2_desc = atc_desc
  )

stopifnot(
  anyDuplicated(atc_level2_labels$atc_level2) == 0L
)

fact_sales_atc <- fact_sales |>
  filter(
    sale_type == "retail",
    !is.na(atc_code)
  )

# Veterinary codes identified in the current source data

veterinary_atc_codes <- c(
  "P52AC13",
  "P53AX65",
  "P54AB51"
)

# Split human and veterinarian sales

fact_sales_atc_human <- fact_sales_atc |>
  filter(!atc_code %in% veterinary_atc_codes)

fact_sales_atc_vet <- fact_sales_atc |>
  filter(atc_code %in% veterinary_atc_codes)

#==============================================================================

# Performance

atc_performance <- fact_sales_atc_human |>
  group_by(atc_code, atc_desc) |>
  summarise(
    products = n_distinct(product_code),
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    profit = sum(profit),
    overall_margin = profit / revenue,
    average_category_revenue_per_receipt = revenue / receipts,
    .groups = "drop"
  ) |>
  mutate(
    package_share = packages_sold / sum(packages_sold),
    revenue_share = revenue / sum(revenue),
    profit_share = profit / sum(profit)
  ) |>
  arrange(desc(packages_sold))


# Granularity of ATC codes

## Level 2

fact_sales_atc_human <- fact_sales_atc_human |>
  mutate(
    atc_level1 = substr(atc_code, 1, 1),
    atc_level2 = substr(atc_code, 1, 3),
    atc_level3 = substr(atc_code, 1, 4),
    atc_level4 = substr(atc_code, 1, 5)
  )

total_human_atc_receipts <- n_distinct(
  fact_sales_atc_human$sale_id
)

atc_level2_performance <- fact_sales_atc_human |>
  group_by(atc_level2) |>
  summarise(
    products = n_distinct(product_code),
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    profit = sum(profit),
    overall_margin = profit / revenue,
    .groups = "drop"
  ) |>
  mutate(
    package_share = packages_sold / sum(packages_sold),
    revenue_share = revenue / sum(revenue),
    profit_share = profit / sum(profit),
    receipt_frequency = receipts / total_human_atc_receipts,
    packages_per_receipt = packages_sold / receipts,
    average_category_revenue_per_receipt = revenue / receipts
  ) |>
  arrange(desc(packages_sold))

# Add official level 2 descriptions

atc_level2_performance <- atc_level2_performance |>
  left_join(
    atc_level2_labels,
    by = "atc_level2"
  ) |>
  relocate(atc_level2_desc, .after = atc_level2)

# Check categories without a matching description

atc_level2_missing_labels <- atc_level2_performance |>
  filter(is.na(atc_level2_desc))

stopifnot(
  nrow(atc_level2_missing_labels) == 0L
)

### Share of packages

atc_level2_concentration <- atc_level2_performance |>
  arrange(desc(packages_sold)) |>
  mutate(
    cumulative_package_share = cumsum(package_share)
  )

atc_categories_for_50 <- which(
  atc_level2_concentration$cumulative_package_share >= 0.50
)[1]

atc_categories_for_75 <- which(
  atc_level2_concentration$cumulative_package_share >= 0.75
)[1]

atc_categories_for_80 <- which(
  atc_level2_concentration$cumulative_package_share >= 0.80
)[1]

atc_categories_for_90 <- which(
  atc_level2_concentration$cumulative_package_share >= 0.90
)[1]

atc_concentration_summary <- tibble(
  threshold = c("50%", "75%", "80%", "90%"),
  categories = c(
    atc_categories_for_50,
    atc_categories_for_75,
    atc_categories_for_80,
    atc_categories_for_90
  )
)

#------------------------------------------------------------------------------
# Product-level drill-down for selected ATC categories
#------------------------------------------------------------------------------

b05_product_performance <- fact_sales_atc_human |>
  filter(atc_level2 == "B05") |>
  group_by(product_code) |>
  summarise(
    product_desc = product_desc[which.max(date)],
    atc_code = atc_code[which.max(date)],
    atc_desc = atc_desc[which.max(date)],
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    profit = sum(profit),
    .groups = "drop"
  ) |>
  arrange(desc(packages_sold), product_code)

top_products_m01_n02 <- fact_sales_atc_human |>
  filter(atc_level2 %in% c("M01", "N02")) |>
  group_by(atc_level2, product_code) |>
  summarise(
    product_desc = product_desc[which.max(date)],
    packages_sold = sum(packages),
    revenue = sum(revenue),
    profit = sum(profit),
    .groups = "drop"
  ) |>
  group_by(atc_level2) |>
  arrange(desc(packages_sold), product_code, .by_group = TRUE) |>
  slice_head(n = 5) |>
  ungroup()
