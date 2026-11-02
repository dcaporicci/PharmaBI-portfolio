#===============================================================================
# PharmaBI
#
# Script: 01_generate_demo_data.R
# Objective: Generate reproducible synthetic demonstration data.
#
# No operational sales data are used as input.
#===============================================================================

library(dplyr)
library(here)

#------------------------------------------------------------------------------
# Reproducibility
#------------------------------------------------------------------------------

demo_seed <- 47031L

set.seed(demo_seed)

#------------------------------------------------------------------------------
# Dedicated demo directories
#------------------------------------------------------------------------------

demo_root <- here("data", "demo")

demo_directories <- file.path(
  demo_root,
  c("facts", "reference", "database", "powerbi")
)

for (directory in demo_directories) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

# Define the future synthetic fact table location
demo_fact_file <- file.path(
  demo_root,
  "facts",
  "fact_sales.rds"
)

message("Synthetic demo workspace initialized.")
message("Demo directory: ", demo_root)

#------------------------------------------------------------------------------
# Synthetic merchandise groups
#------------------------------------------------------------------------------

demo_gm <- tibble(
  gm_code = sprintf("D%04d", seq_len(12L)),
  gm_desc = c(
    "OTC medicines",
    "Other non-prescription medicines",
    "Supplements",
    "Skin care",
    "Sun care",
    "Oral care",
    "Eye care",
    "Nasal care",
    "Medical supplies",
    "Personal care",
    "Baby care",
    "Veterinary products"
  )
)

#------------------------------------------------------------------------------
# Synthetic product catalogue
#------------------------------------------------------------------------------

demo_product_count <- 240L

demo_products <- tibble(
  product_code = sprintf(
    "D%08d",
    seq_len(demo_product_count)
  ),
  gm_code = rep(
    demo_gm$gm_code,
    each = 20L
  ),
  manufacturer_number = rep(
    seq_len(8L),
    length.out = demo_product_count
  )
) |>
  left_join(demo_gm, by = "gm_code") |>
  mutate(
    product_desc = paste(
      "DEMO",
      gm_desc,
      sprintf("%03d", seq_len(n()))
    ),
    manufacturer_code = sprintf(
      "DM%03d",
      manufacturer_number
    ),
    manufacturer_desc = sprintf(
      "Demo manufacturer %02d",
      manufacturer_number
    ),
    unit_net_price = round(
      runif(n(), min = 2, max = 38),
      3
    ),
    unit_cost = round(
      unit_net_price * runif(n(), min = 0.45, max = 0.82),
      3
    )
  ) |>
  select(-manufacturer_number)

# Validate the catalogue before generating sales
stopifnot(
  !anyNA(demo_products),
  anyDuplicated(demo_products$product_code) == 0L,
  all(demo_products$unit_net_price > 0),
  all(demo_products$unit_cost >= 0)
)

message("Synthetic product catalogue created.")

#------------------------------------------------------------------------------
# Public ATC reference — no operational sales data
#------------------------------------------------------------------------------

public_atc_reference_file <- here(
  "data", "reference", "atc_reference.rds"
)

if (!file.exists(public_atc_reference_file)) {
  stop(
    paste(
      "Public ATC reference not found.",
      "Run R/reference/01_build_atc_reference.R first."
    ),
    call. = FALSE
  )
}

demo_atc_reference <- readRDS(
  public_atc_reference_file
) |>
  select(atc_code, atc_desc, atc_level)

stopifnot(
  nrow(demo_atc_reference) > 0L,
  !anyNA(demo_atc_reference),
  anyDuplicated(demo_atc_reference$atc_code) == 0L
)

# Level 2 descriptions for the dashboards
demo_atc_level2 <- demo_atc_reference |>
  filter(atc_level == 2L) |>
  transmute(
    atc_level2 = atc_code,
    atc_level2_desc = atc_desc
  )

# Categories chosen for the fictional scenario
demo_human_atc_groups <- c(
  "A01", "A02", "A06", "A07",
  "B05", "D01", "M01", "M02",
  "N02", "R01", "R05", "R06"
)

# Available full ATC codes within those categories
demo_human_atc_pool <- demo_atc_reference |>
  filter(
    atc_level == 5L,
    substr(atc_code, 1, 3) %in% demo_human_atc_groups
  ) |>
  arrange(atc_code)

stopifnot(
  all(
    demo_human_atc_groups %in%
      substr(demo_human_atc_pool$atc_code, 1, 3)
  )
)

message("Public ATC reference prepared for the synthetic scenario.")

#------------------------------------------------------------------------------
# Assign human ATC codes to fictional medicinal products
#------------------------------------------------------------------------------

demo_products <- demo_products |>
  mutate(
    atc_code = NA_character_,
    atc_desc = NA_character_
  )

demo_human_rows <- which(
  demo_products$gm_code %in% c("D0001", "D0002")
)

# Distribute products across all twelve selected ATC groups
demo_group_assignment <- rep(
  demo_human_atc_groups,
  length.out = length(demo_human_rows)
)

for (position in seq_along(demo_human_rows)) {

  candidates <- demo_human_atc_pool |>
    filter(
      substr(atc_code, 1, 3) ==
        demo_group_assignment[position]
    )

  selected_row <- sample.int(
    nrow(candidates),
    size = 1L
  )

  product_row <- demo_human_rows[position]

  demo_products$atc_code[product_row] <-
    candidates$atc_code[selected_row]

  demo_products$atc_desc[product_row] <-
    candidates$atc_desc[selected_row]
}

#------------------------------------------------------------------------------
# Veterinary codes handled by the current application
#------------------------------------------------------------------------------

demo_vet_codes <- c(
  "P52AC13",
  "P53AX65",
  "P54AB51"
)

demo_vet_rows <- which(
  demo_products$gm_code == "D0012"
)

demo_vet_assignment <- rep(
  seq_along(demo_vet_codes),
  length.out = length(demo_vet_rows)
)

demo_products$atc_code[demo_vet_rows] <-
  demo_vet_codes[demo_vet_assignment]

demo_products$atc_desc[demo_vet_rows] <- paste(
  "Demo veterinary classification",
  demo_vet_assignment
)

# Code and description must be missing together
stopifnot(
  !any(
    xor(
      is.na(demo_products$atc_code),
      is.na(demo_products$atc_desc)
    )
  )
)

message("ATC assignments completed for the synthetic catalogue.")

#------------------------------------------------------------------------------
# Synthetic calendar and sales window
#------------------------------------------------------------------------------

demo_calendar <- tibble(
  date = seq.Date(
    as.Date("2026-01-01"),
    as.Date("2026-12-31"),
    by = "day"
  )
)

demo_sales_start <- as.Date("2026-01-05")
demo_sales_end <- as.Date("2026-09-20")

demo_closed_dates <- as.Date(
  c("2026-04-12", "2026-04-13")
)

demo_open_dates <- demo_calendar$date[
  demo_calendar$date >= demo_sales_start &
    demo_calendar$date <= demo_sales_end &
    !demo_calendar$date %in% demo_closed_dates
]

#------------------------------------------------------------------------------
# Synthetic retail receipt headers
#------------------------------------------------------------------------------

demo_receipt_count <- 4800L

stopifnot(
  length(demo_open_dates) > 0L,
  demo_receipt_count >= length(demo_open_dates)
)

# Assign one receipt to every open date, then distribute the remainder
demo_extra_receipt_dates <- demo_open_dates[
  sample.int(
    length(demo_open_dates),
    size = demo_receipt_count - length(demo_open_dates),
    replace = TRUE
  )
]

demo_receipt_dates <- sort(
  c(demo_open_dates, demo_extra_receipt_dates)
)

demo_receipts <- tibble(
  date = demo_receipt_dates
) |>
  group_by(date) |>
  mutate(
    number_sales = as.integer(row_number())
  ) |>
  ungroup() |>
  mutate(
    sale_id = paste(
      "DEMO",
      format(date, "%Y-%m-%d"),
      sprintf("%05d", number_sales),
      sep = "|"
    ),
    sale_type = "retail"
  )

stopifnot(
  nrow(demo_receipts) == demo_receipt_count,
  anyDuplicated(demo_receipts$sale_id) == 0L,
  !anyNA(demo_receipts),
  all(demo_receipts$date %in% demo_open_dates)
)

message("Synthetic retail receipt headers created.")

#------------------------------------------------------------------------------
# Format synthetic time slots
#------------------------------------------------------------------------------

demo_format_time_slot <- function(minutes, slot_width) {

  slot_start <- (minutes %/% slot_width) * slot_width
  slot_end <- slot_start + slot_width - 1L

  sprintf(
    "%02d:%02d - %02d:%02d",
    slot_start %/% 60L,
    slot_start %% 60L,
    slot_end %/% 60L,
    slot_end %% 60L
  )
}

#------------------------------------------------------------------------------
# Receipt times and planned basket sizes
#------------------------------------------------------------------------------

demo_receipts <- demo_receipts |>
  group_by(date) |>
  mutate(
    minute_of_day = sort(
      sample.int(
        660L,
        size = n(),
        replace = TRUE
      )
    ) + 540L - 1L
  ) |>
  ungroup() |>
  mutate(
    time_slot_quarter = demo_format_time_slot(
      minute_of_day, 15L
    ),
    time_slot_half = demo_format_time_slot(
      minute_of_day, 30L
    ),
    time_slot_hour = demo_format_time_slot(
      minute_of_day, 60L
    ),
    basket_size = sample.int(
      8L,
      size = n(),
      replace = TRUE,
      prob = c(
        0.620, 0.230, 0.090, 0.035,
        0.015, 0.006, 0.003, 0.001
      )
    )
  ) |>
  select(-minute_of_day)

message("Synthetic receipt times and basket sizes assigned.")

#------------------------------------------------------------------------------
# Fictional product popularity and recurring pairs
#------------------------------------------------------------------------------

demo_product_weights <- setNames(
  runif(nrow(demo_products), min = 0.3, max = 3),
  demo_products$product_code
)

demo_bundles <- list(
  demo_products$product_code[
    demo_products$gm_code == "D0004"
  ][1:2],
  demo_products$product_code[
    demo_products$gm_code == "D0006"
  ][1:2],
  demo_products$product_code[
    demo_products$gm_code == "D0003"
  ][1:2]
)

#------------------------------------------------------------------------------
# Draw distinct products for one receipt
#------------------------------------------------------------------------------

demo_draw_products <- function(basket_size) {

  selected_codes <- character(0)

  if (basket_size >= 2L && runif(1) < 0.20) {
    selected_codes <- demo_bundles[[
      sample.int(length(demo_bundles), size = 1L)
    ]]
  }

  available_codes <- setdiff(
    demo_products$product_code,
    selected_codes
  )

  additional_codes <- sample(
    available_codes,
    size = basket_size - length(selected_codes),
    replace = FALSE,
    prob = demo_product_weights[available_codes]
  )

  c(selected_codes, additional_codes)
}

#------------------------------------------------------------------------------
# Build receipt-product rows
#------------------------------------------------------------------------------

demo_basket_products <- bind_rows(
  lapply(
    seq_len(nrow(demo_receipts)),
    function(receipt_index) {
      tibble(
        sale_id = demo_receipts$sale_id[receipt_index],
        product_code = demo_draw_products(
          demo_receipts$basket_size[receipt_index]
        )
      )
    }
  )
)

#------------------------------------------------------------------------------
# Validate receipt composition
#------------------------------------------------------------------------------

demo_basket_size_check <- demo_basket_products |>
  count(sale_id, name = "actual_products") |>
  left_join(
    demo_receipts |>
      select(sale_id, basket_size),
    by = "sale_id"
  )

stopifnot(
  anyDuplicated(
    demo_basket_products[c("sale_id", "product_code")]
  ) == 0L,
  nrow(demo_basket_size_check) == nrow(demo_receipts),
  all(
    demo_basket_size_check$actual_products ==
      demo_basket_size_check$basket_size
  )
)

message("Synthetic receipt-product rows created and validated.")

#------------------------------------------------------------------------------
# Build the synthetic retail fact table
#------------------------------------------------------------------------------

demo_fact_sales <- demo_basket_products |>
  left_join(
    demo_receipts,
    by = "sale_id"
  ) |>
  left_join(
    demo_products,
    by = "product_code"
  ) |>
  mutate(
    packages = sample.int(
      4L,
      size = n(),
      replace = TRUE,
      prob = c(0.820, 0.140, 0.035, 0.005)
    ),
    revenue = round(
      packages * unit_net_price,
      3
    ),
    costs = round(
      packages * unit_cost,
      3
    ),
    profit = round(revenue - costs, 3),
    margin = profit / revenue
  ) |>
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
    packages,
    sale_type
  ) |>
  arrange(date, sale_id, product_code)

#------------------------------------------------------------------------------
# Validate the base synthetic fact table
#------------------------------------------------------------------------------

stopifnot(
  nrow(demo_fact_sales) == nrow(demo_basket_products),
  ncol(demo_fact_sales) == 20L,
  n_distinct(demo_fact_sales$sale_id) == nrow(demo_receipts),
  !anyNA(
    demo_fact_sales |>
      select(-atc_code, -atc_desc)
  ),
  all(
    abs(
      demo_fact_sales$revenue -
        demo_fact_sales$costs -
        demo_fact_sales$profit
    ) < 1e-10
  )
)

message("Base synthetic retail fact table created and validated.")

#------------------------------------------------------------------------------
# Controlled synthetic scenarios
#------------------------------------------------------------------------------

demo_return_count <- 8L
demo_discount_count <- 12L

# Three fictional products with zero recorded costs
demo_zero_cost_codes <- sample(
  demo_products$product_code,
  size = 3L,
  replace = FALSE
)

demo_fact_sales <- demo_fact_sales |>
  mutate(
    costs = if_else(
      product_code %in% demo_zero_cost_codes,
      0,
      costs
    )
  )

# Keep returns and below-cost sales separate from zero-cost products
demo_eligible_rows <- which(
  !demo_fact_sales$product_code %in% demo_zero_cost_codes
)

demo_exception_rows <- sample(
  demo_eligible_rows,
  size = demo_return_count + demo_discount_count,
  replace = FALSE
)

demo_return_rows <- head(
  demo_exception_rows,
  demo_return_count
)

demo_discount_rows <- tail(
  demo_exception_rows,
  demo_discount_count
)

# Simulate below-cost sales through reduced revenue
demo_fact_sales$revenue[demo_discount_rows] <- round(
  demo_fact_sales$costs[demo_discount_rows] * 0.85,
  3
)

# Reverse quantities and amounts for returned products
demo_fact_sales$packages[demo_return_rows] <-
  -demo_fact_sales$packages[demo_return_rows]

demo_fact_sales$revenue[demo_return_rows] <-
  -demo_fact_sales$revenue[demo_return_rows]

demo_fact_sales$costs[demo_return_rows] <-
  -demo_fact_sales$costs[demo_return_rows]

# Recalculate dependent measures after the adjustments
demo_fact_sales <- demo_fact_sales |>
  mutate(
    profit = round(revenue - costs, 3),
    margin = profit / revenue
  )

stopifnot(
  sum(demo_fact_sales$packages < 0) == demo_return_count,
  sum(demo_fact_sales$margin < 0) == demo_discount_count,
  all(
    abs(
      demo_fact_sales$revenue -
        demo_fact_sales$costs -
        demo_fact_sales$profit
    ) < 1e-10
  )
)

message("Controlled synthetic scenarios applied and validated.")

#------------------------------------------------------------------------------
# Synthetic non-retail transactions
#------------------------------------------------------------------------------

demo_non_retail_headers <- demo_receipts |>
  slice(
    sample.int(
      nrow(demo_receipts),
      size = 3L,
      replace = FALSE
    )
  ) |>
  mutate(
    sale_id = paste(
      "DEMO-NONRETAIL",
      format(date, "%Y-%m-%d"),
      sprintf("%03d", row_number()),
      sep = "|"
    ),
    number_sales = 0L,
    sale_type = "non_retail"
  ) |>
  select(-basket_size)

demo_non_retail_products <- bind_rows(
  lapply(
    seq_len(nrow(demo_non_retail_headers)),
    function(transaction_index) {
      tibble(
        sale_id =
          demo_non_retail_headers$sale_id[transaction_index],
        product_code = sample(
          demo_products$product_code,
          size = 6L,
          replace = FALSE
        )
      )
    }
  )
)

demo_non_retail_sales <- demo_non_retail_products |>
  left_join(demo_non_retail_headers, by = "sale_id") |>
  left_join(demo_products, by = "product_code") |>
  mutate(
    packages = sample(10:25, size = n(), replace = TRUE),
    revenue = round(packages * unit_net_price, 3),
    costs = if_else(
      product_code %in% demo_zero_cost_codes,
      0,
      round(packages * unit_cost, 3)
    ),
    profit = round(revenue - costs, 3),
    margin = profit / revenue
  ) |>
  select(all_of(names(demo_fact_sales)))

# Combine both sale types
demo_fact_sales <- bind_rows(
  demo_fact_sales,
  demo_non_retail_sales
) |>
  arrange(date, sale_id, product_code)

stopifnot(
  nrow(demo_non_retail_sales) == 18L,
  anyDuplicated(
    demo_fact_sales[c("sale_id", "product_code")]
  ) == 0L,
  all(
    abs(
      demo_fact_sales$revenue -
        demo_fact_sales$costs -
        demo_fact_sales$profit
    ) < 1e-10
  )
)

#------------------------------------------------------------------------------
# Save synthetic data and the public reference snapshot
#------------------------------------------------------------------------------

saveRDS(
  demo_fact_sales,
  demo_fact_file
)

saveRDS(
  demo_atc_reference,
  file.path(
    demo_root,
    "reference",
    "atc_reference.rds"
  )
)

message("Synthetic dataset saved successfully.")
message("Fact table: ", demo_fact_file)
