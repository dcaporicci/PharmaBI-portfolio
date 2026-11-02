#===============================================================================
# PharmaBI
#
# Script: 03_gm_analysis.R
#
# Obiettivo:
# Getting insight on commodity cateogory performances
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

fact_sales_retail <- fact_sales |>
  filter(sale_type == "retail")

# Aggregation table

gm_performance <- fact_sales_retail |>
  group_by(gm_code, gm_desc) |>
  summarise(
    products = n_distinct(product_code),
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    profit = sum(profit),
    overall_margin = profit / revenue,
    average_category_revenue_per_receipt = revenue / receipts,
    .groups = "drop"
  )


# Shares

gm_performance <- gm_performance |>
  mutate(
    package_share = packages_sold / sum(packages_sold),
    revenue_share = revenue / sum(revenue),
    profit_share = profit / sum(profit)
  ) |>
  arrange(desc(profit))


# Top 15

## - driving categories by volume,
## - driving categories by value,
## - profit-driving categories,
## - high-marginality categories.

top_gm_profit <- gm_performance |>
  slice_max(profit, n = 15)

top_gm_revenue <- gm_performance |>
  slice_max(revenue, n = 15)

top_gm_packages <- gm_performance |>
  slice_max(packages_sold, n = 15)

top_gm_margin <- gm_performance |>
  filter(packages_sold >= 30) |>
  slice_max(overall_margin, n = 15)

# How much concentrated are the first categories on the total

gm_concentration <- gm_performance |>
  arrange(desc(profit)) |>
  mutate(
    cumulative_profit_share = cumsum(profit_share),
    cumulative_revenue_share = cumsum(revenue_share),
    cumulative_package_share = cumsum(package_share)
  )

# Thresholds

gm_concentration_summary <- gm_concentration |>
  summarise(
    categories_for_50_profit =
      which(cumulative_profit_share >= 0.50)[1],
    categories_for_75_profit =
      which(cumulative_profit_share >= 0.75)[1],
    categories_for_80_profit =
      which(cumulative_profit_share >= 0.80)[1],
    categories_for_90_profit =
      which(cumulative_profit_share >= 0.90)[1]
  )

# Top gm for 80% profit

categories_for_80_profit <- which(
  gm_concentration$cumulative_profit_share >= 0.80
)[1]

top_gm_80_profit <- gm_concentration |>
  slice_head(n = categories_for_80_profit)


# Top gm for 50%, 75% and 90%

categories_for_50_profit <- which(
  gm_concentration$cumulative_profit_share >= 0.50
)[1]

categories_for_75_profit <- which(
  gm_concentration$cumulative_profit_share >= 0.75
)[1]

categories_for_90_profit <- which(
  gm_concentration$cumulative_profit_share >= 0.90
)[1]
