#===============================================================================
# PharmaBI
#
# Script: 05_build_fact_sales.R
#
# Objective:
# Build and save the final sales fact table.
#
# Author:
# Danilo Caporicci
#===============================================================================

library(dplyr)
library(here)

#-------------------------------------------------------------------------------
# Load private receipt classification rules
#-------------------------------------------------------------------------------

classification_file <- here("config", "sales_classification.R")

if (!file.exists(classification_file)) {
  stop(
    paste(
      "Missing config/sales_classification.R.",
      "Define non_retail_sale_ids locally before running the private pipeline."
    ),
    call. = FALSE
  )
}

classification_env <- new.env(parent = baseenv())
sys.source(classification_file, envir = classification_env)

if (!exists(
  "non_retail_sale_ids",
  envir = classification_env,
  inherits = FALSE
)) {
  stop(
    "config/sales_classification.R must define non_retail_sale_ids.",
    call. = FALSE
  )
}

non_retail_sale_ids <- get(
  "non_retail_sale_ids",
  envir = classification_env,
  inherits = FALSE
)

if (
  !is.character(non_retail_sale_ids) ||
  anyNA(non_retail_sale_ids) ||
  any(!nzchar(trimws(non_retail_sale_ids))) ||
  any(non_retail_sale_ids != trimws(non_retail_sale_ids)) ||
  anyDuplicated(non_retail_sale_ids) != 0L
) {
  stop(
    paste(
      "non_retail_sale_ids must be a character vector of unique, non-blank IDs",
      "without surrounding whitespace. Use character(0) only when no",
      "non-retail receipts need classification."
    ),
    call. = FALSE
  )
}

#-------------------------------------------------------------------------------
# Build fact_sales
#-------------------------------------------------------------------------------

fact_sales <- sales_clean %>%
  left_join(
    dim_products_gm %>%
      select(product_code, gm_code, gm_desc),
    by = "product_code"
  ) %>%
  left_join(
    dim_products_atc %>%
      select(product_code, atc_code, atc_desc),
    by = "product_code"
  ) %>%
  select(
    date,
    time_slot_quarter,
    time_slot_half,
    time_slot_hour,
    sale_id,
    number_sales,
    manufacturer_code,
    manufacturer_desc,
    product_code,
    product_desc,
    gm_code,
    gm_desc,
    atc_code,
    atc_desc,
    revenue,
    costs,
    profit,
    margin,
    packages
  ) %>%
  mutate(
    manufacturer_code = as.character(manufacturer_code),
    number_sales = as.integer(number_sales),
    packages = as.integer(packages)
  )

fact_sales <- fact_sales |>
  mutate(
    sale_type = if_else(
      sale_id %in% non_retail_sale_ids,
      "non_retail",
      "retail"
    )
  )

#-------------------------------------------------------------------------------
# Mandatory validation checks
#-------------------------------------------------------------------------------

# The joins must not change the number of sales rows
stopifnot(nrow(fact_sales) == nrow(sales_clean))

# The logical key must remain unique
stopifnot(
  !anyDuplicated(
    fact_sales[c("sale_id", "product_code")]
  )
)

# Every valid sold product must have a GM classification
stopifnot(
  !any(is.na(fact_sales$gm_code)),
  !any(is.na(fact_sales$gm_desc))
)

# Required product identifiers must be present
stopifnot(
  !any(is.na(fact_sales$product_code)),
  !any(is.na(fact_sales$product_desc))
)

#-------------------------------------------------------------------------------
# Save final fact table
#-------------------------------------------------------------------------------

saveRDS(
  fact_sales,
  here("data", "facts", "fact_sales.rds")
)

message("fact_sales successfully built and saved.")
