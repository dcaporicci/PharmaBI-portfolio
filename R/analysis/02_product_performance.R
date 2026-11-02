#===============================================================================
# PharmaBI
#
# Script: 02_product_performance.R
#
# Obiettivo:
# Getting insight on product performances
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

# Metrics

total_retail_receipts <- n_distinct(fact_sales_retail$sale_id)

total_retail_receipts <- n_distinct(fact_sales_retail$sale_id)

product_performance <- fact_sales_retail |>
  group_by(product_code) |>
  summarise(
    product_desc = product_desc[which.max(date)],
    packages_sold = sum(packages),
    receipts = n_distinct(sale_id),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    profit_per_unit = profit / packages_sold,
    average_net_revenue_per_package = revenue / packages_sold,
    overall_margin = profit / revenue,
    .groups = "drop"
  ) |>
  mutate(
    receipt_frequency = receipts / total_retail_receipts,
    packages_per_receipt = packages_sold / receipts,
    zero_cost_flag = costs == 0
  ) |>
  arrange(desc(profit))

# Validate product grain and reconciliation with retail totals
stopifnot(
  anyDuplicated(product_performance$product_code) == 0L,
  nrow(product_performance) ==
    n_distinct(fact_sales_retail$product_code),
  sum(product_performance$packages_sold) ==
    sum(fact_sales_retail$packages),
  isTRUE(all.equal(
    sum(product_performance$revenue),
    sum(fact_sales_retail$revenue)
  )),
  isTRUE(all.equal(
    sum(product_performance$profit),
    sum(fact_sales_retail$profit)
  ))
)

# ------------------------------------------------------------------------------

# Top lists

top_profit <- product_performance |>
  slice_max(profit, n = 20)

top_packages <- product_performance |>
  slice_max(packages_sold, n = 20)

top_revenue <- product_performance |>
  slice_max(revenue, n = 20)

top_frequency <- product_performance |>
  slice_max(receipt_frequency, n = 20)

top_margin <- product_performance |>
  filter(packages_sold >= 10) |>
  slice_max(overall_margin, n = 20)

# ------------------------------------------------------------------------------

# Product segmentation

## Overview

### Summary
summary(product_performance$packages_sold)
summary(product_performance$profit)
summary(product_performance$receipt_frequency)

### Quantile
quantile(
  product_performance$packages_sold,
  probs = c(0.25, 0.50, 0.75, 0.90)
)

quantile(
  product_performance$profit,
  probs = c(0.25, 0.50, 0.75, 0.90)
)

## Segmentation

rotation_threshold <- quantile(
  product_performance$packages_sold,
  0.75
)

profit_threshold <- quantile(
  product_performance$profit,
  0.75
)


product_performance <- product_performance |>
  mutate(
    performance_segment = case_when(
      packages_sold >= rotation_threshold &
        profit >= profit_threshold ~ "Core products",

      packages_sold >= rotation_threshold &
        profit < profit_threshold ~ "High sales volume - low total profit",

      packages_sold < rotation_threshold &
        profit >= profit_threshold ~ "Low sales volume - high total profit",

      TRUE ~ "Low sales volume - low total profit"
    )
  )

product_performance |>
  count(performance_segment)


# Contribution of each segment to total retail sales and profit

segment_summary <- product_performance |>
  group_by(performance_segment) |>
  summarise(
    products = n(),
    packages_sold = sum(packages_sold),
    revenue = sum(revenue),
    profit = sum(profit),
    .groups = "drop"
  ) |>
  mutate(
    product_share = products / sum(products),
    package_share = packages_sold / sum(packages_sold),
    revenue_share = revenue / sum(revenue),
    profit_share = profit / sum(profit)
  ) |>
  arrange(desc(profit))

# ------------------------------------------------------------------------------

# Which products are included in each segment

core_products <- product_performance |>
  filter(performance_segment == "Core products") |>
  arrange(desc(profit))

high_rotation_low_profit <- product_performance |>
  filter(performance_segment == "High sales volume - low total profit") |>
  arrange(desc(packages_sold))

low_rotation_high_profit <- product_performance |>
  filter(performance_segment == "Low sales volume - high total profit") |>
  arrange(desc(profit))

low_rotation_low_profit <- product_performance |>
  filter(performance_segment == "Low sales volume - low total profit") |>
  arrange(desc(profit))



# Check whether a product code appears under multiple descriptions
product_performance |>
  count(product_code, name = "rows") |>
  filter(rows > 1)

# Count products with zero total recorded costs
product_performance |>
  count(zero_cost_flag)

# Display segmentation thresholds
tibble(
  packages_threshold = as.numeric(rotation_threshold),
  profit_threshold = as.numeric(profit_threshold)
)

# Display segment contributions
#print(segment_summary, width = Inf)
