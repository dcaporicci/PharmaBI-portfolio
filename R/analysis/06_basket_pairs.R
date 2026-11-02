#===============================================================================
# PharmaBI
#
# Script: 06_basket_pairs.R
# Objective: Identify products purchased together in retail receipts
#===============================================================================

library(dplyr)
library(here)

# Reuse the retail data and basket analysis
source(
  here("R", "analysis", "05_basket_analysis.R"),
  local = TRUE
)

# One row per product present in a receipt
basket_products <- fact_sales_retail |>
  distinct(sale_id, product_code)

# Generate product combinations within each receipt
basket_pairs_raw <- basket_products |>
  inner_join(
    basket_products,
    by = "sale_id",
    suffix = c("_a", "_b"),
    relationship = "many-to-many"
  )

# Keep each unordered pair once per receipt
basket_pairs <- basket_pairs_raw |>
  filter(product_code_a < product_code_b)

# Count how many receipts contain each product pair
pair_frequency <- basket_pairs |>
  count(
    product_code_a,
    product_code_b,
    name = "receipts_together"
  ) |>
  arrange(
    desc(receipts_together),
    product_code_a,
    product_code_b
  )

# Build one display label per product code
product_labels <- fact_sales_retail |>
  group_by(product_code) |>
  summarise(
    product_desc = product_desc[which.max(date)],
    .groups = "drop"
  )

# Add product descriptions to both sides of each pair
pair_performance <- pair_frequency |>
  left_join(
    product_labels |>
      rename(
        product_code_a = product_code,
        product_desc_a = product_desc
      ),
    by = "product_code_a",
    relationship = "many-to-one"
  ) |>
  left_join(
    product_labels |>
      rename(
        product_code_b = product_code,
        product_desc_b = product_desc
      ),
    by = "product_code_b",
    relationship = "many-to-one"
  ) |>
  relocate(product_desc_a, .after = product_code_a) |>
  relocate(product_desc_b, .after = product_code_b)

# Control
stopifnot(
  nrow(pair_performance) == nrow(pair_frequency),
  !anyNA(pair_performance$product_desc_a),
  !anyNA(pair_performance$product_desc_b)
)

# Calculate pair support across all retail receipts
total_retail_receipts <- n_distinct(
  fact_sales_retail$sale_id
)

pair_performance <- pair_performance |>
  mutate(
    support = receipts_together / total_retail_receipts
  )

# Count receipts containing each individual product
product_receipt_counts <- basket_products |>
  count(
    product_code,
    name = "product_receipts"
  )

# Add individual product counts and directional confidence
pair_metrics <- pair_performance |>
  left_join(
    product_receipt_counts |>
      rename(
        product_code_a = product_code,
        receipts_a = product_receipts
      ),
    by = "product_code_a",
    relationship = "many-to-one"
  ) |>
  left_join(
    product_receipt_counts |>
      rename(
        product_code_b = product_code,
        receipts_b = product_receipts
      ),
    by = "product_code_b",
    relationship = "many-to-one"
  ) |>
  mutate(
    confidence_a_to_b = receipts_together / receipts_a,
    confidence_b_to_a = receipts_together / receipts_b
  )

# Compare observed co-purchases with an independence baseline
pair_metrics <- pair_metrics |>
  mutate(
    support_a = receipts_a / total_retail_receipts,
    support_b = receipts_b / total_retail_receipts,
    expected_receipts_together =
      support_a * support_b * total_retail_receipts,
    lift = receipts_together / expected_receipts_together
  )

# Select pairs with a minimum observed receipt count
minimum_pair_receipts <- 5L

recurrent_pairs <- pair_metrics |>
  filter(
    receipts_together >= minimum_pair_receipts
  ) |>
  arrange(
    desc(receipts_together),
    product_code_a,
    product_code_b
  )

# Compare how many pairs remain at different count thresholds
pair_threshold_summary <- pair_metrics |>
  summarise(
    pairs_at_least_2 = sum(receipts_together >= 2L),
    pairs_at_least_3 = sum(receipts_together >= 3L),
    pairs_at_least_5 = sum(receipts_together >= 5L),
    pairs_at_least_10 = sum(receipts_together >= 10L)
  )

# Validate pair counts and aggregation
expected_pair_occurrences <- sum(
  basket_sales$unique_products *
    (basket_sales$unique_products - 1) / 2
)

stopifnot(
  nrow(basket_pairs) == expected_pair_occurrences,

  anyDuplicated(
    basket_pairs[c(
      "sale_id",
      "product_code_a",
      "product_code_b"
    )]
  ) == 0L,

  sum(pair_frequency$receipts_together) == nrow(basket_pairs),

  nrow(pair_metrics) == nrow(pair_frequency),

  all(pair_metrics$receipts_together <= pair_metrics$receipts_a),

  all(pair_metrics$receipts_together <= pair_metrics$receipts_b)
)

message("Basket pair validation passed.")
