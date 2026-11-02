#===============================================================================
# PharmaBI
#
# Script: 01_sales_overview.R
#
# Obiettivo:
# Setting up the first block of KPI
#
# Autore:
# Danilo Caporicci
#===============================================================================


#------------------------------------------------------------------------------
# Librerie
#------------------------------------------------------------------------------

library(dplyr)
library(here)

# Load fact_sales

fact_sales <- readRDS(
  here("data", "facts", "fact_sales.rds")
)

# Economic summary by sale type

sales_by_type <- fact_sales |>
  group_by(sale_type) |>
  summarise(
    transactions = n_distinct(sale_id),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    overall_margin = profit / revenue,
    .groups = "drop"
  )

# Retail data for receipt and temporal analysis

fact_sales_retail <- fact_sales |>
  filter(sale_type == "retail")

# Looking at some metrics

sales_overview <- fact_sales_retail |>
  summarise(
    start_date = min(date),
    end_date = max(date),
    receipts = n_distinct(sale_id),
    unique_products = n_distinct(product_code),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    overall_margin = profit / revenue,
    average_receipt_value = revenue / receipts,
    average_profit_per_receipt = profit / receipts
  )


# For a better view of the data

sales_overview_display <- sales_overview |>
  mutate(
    revenue = round(revenue, 2),
    costs = round(costs, 2),
    profit = round(profit, 2),
    overall_margin = round(overall_margin * 100, 2),
    average_receipt_value = round(average_receipt_value, 2),
    average_profit_per_receipt = round(average_profit_per_receipt, 2)
  )

# Sales by month

sales_monthly <- fact_sales_retail |>
  mutate(month = format(date, "%Y-%m")) |>
  group_by(month) |>
  summarise(
    active_days = n_distinct(date),
    receipts = n_distinct(sale_id),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    costs = sum(costs),
    profit = sum(profit),
    overall_margin = profit / revenue,
    average_receipt_value = revenue / receipts,
    receipts_per_day = receipts / active_days,
    revenue_per_day = revenue / active_days,
    profit_per_day = profit / active_days
  )

# Sales by weekday

sales_weekday <- fact_sales_retail |>
  mutate(
    weekday = factor(
      as.integer(format(date, "%u")),
      levels = 1:7,
      labels = c(
        "lunedì",
        "martedì",
        "mercoledì",
        "giovedì",
        "venerdì",
        "sabato",
        "domenica"
      ),
      ordered = TRUE
    )
  ) |>
  group_by(weekday) |>
  summarise(
    active_days = n_distinct(date),
    receipts = n_distinct(sale_id),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    profit = sum(profit),
    receipts_per_day = receipts / active_days,
    packages_per_day = packages_sold / active_days,
    revenue_per_day = revenue / active_days,
    profit_per_day = profit / active_days,
    average_receipt_value = revenue / receipts,
    overall_margin = profit / revenue
  )

# Sales hourly

sales_hourly <- fact_sales_retail |>
  group_by(time_slot_hour) |>
  summarise(
    receipts = n_distinct(sale_id),
    packages_sold = sum(packages),
    revenue = sum(revenue),
    profit = sum(profit),
    average_receipt_value = revenue / receipts,
    overall_margin = profit / revenue
  ) |>
  arrange(time_slot_hour)
