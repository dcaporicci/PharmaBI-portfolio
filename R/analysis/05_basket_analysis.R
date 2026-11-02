#===============================================================================
# PharmaBI
# Script: 05_basket_analysis.R
# Objective: Describe retail receipt structure before analysing co-purchases
#===============================================================================

library(dplyr)
library(here)

fact_sales <- readRDS(
  here("data", "facts", "fact_sales.rds")
)

fact_sales_retail <- fact_sales |>
  filter(sale_type == "retail")

#------------------------------------------------------------------------------
# Validate receipt identifiers and required values
#------------------------------------------------------------------------------

stopifnot(
  nrow(fact_sales_retail) > 0L,
  !anyNA(fact_sales_retail[c(
    "sale_id", "date", "product_code", "packages", "revenue", "costs", "profit"
  )])
)

receipt_dates <- fact_sales_retail |>
  distinct(sale_id, date)

if (anyDuplicated(receipt_dates$sale_id) != 0L) {
  stop("Some sale_id values occur on multiple dates. Review receipt identifiers before analysing baskets.")
}

#------------------------------------------------------------------------------
# One row per retail receipt
#------------------------------------------------------------------------------

basket_sales <- fact_sales_retail |>
  group_by(sale_id) |>
  summarise(
    date = first(date),
    unique_products = n_distinct(product_code),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    .groups = "drop"
  ) |>
  arrange(date, sale_id)

# Distinct products and package quantities measure different basket properties.
# A receipt with three packages of one product has unique_products = 1.

stopifnot(
  nrow(basket_sales) == n_distinct(fact_sales_retail$sale_id),
  sum(basket_sales$packages_sold) == sum(fact_sales_retail$packages),
  isTRUE(all.equal(sum(basket_sales$revenue), sum(fact_sales_retail$revenue))),
  isTRUE(all.equal(sum(basket_sales$costs), sum(fact_sales_retail$costs))),
  isTRUE(all.equal(sum(basket_sales$profit), sum(fact_sales_retail$profit)))
)

#------------------------------------------------------------------------------
# Overall basket structure
#------------------------------------------------------------------------------

basket_overview <- basket_sales |>
  summarise(
    receipts = n(),
    single_product_receipts = sum(unique_products == 1L),
    multi_product_receipts = sum(unique_products >= 2L),
    multi_product_receipt_share = multi_product_receipts / receipts,
    average_unique_products = mean(unique_products),
    median_unique_products = median(unique_products),
    maximum_unique_products = max(unique_products),
    average_packages = mean(packages_sold),
    average_net_revenue_per_receipt = mean(revenue),
    median_net_revenue_per_receipt = median(revenue)
  )

#------------------------------------------------------------------------------
# Distribution by number of distinct products in a receipt
#------------------------------------------------------------------------------

basket_size_distribution <- basket_sales |>
  group_by(unique_products) |>
  summarise(
    receipts = n(),
    packages_sold = sum(packages_sold),
    revenue = sum(revenue),
    profit = sum(profit),
    .groups = "drop"
  ) |>
  mutate(
    receipt_share = receipts / nrow(basket_sales),
    average_net_revenue_per_receipt = revenue / receipts
  ) |>
  arrange(unique_products)

# No display rounding is applied to analytical objects.
# Co-purchase pairs will be counted once per containing receipt in the next step.
