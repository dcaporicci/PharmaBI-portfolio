#===============================================================================
# PharmaBI
#
# Script: test_validate_fact_sales.R
#
# Objective:
# Test the fact validator using the synthetic demo and controlled invalid copies.
#
# Author:
# Danilo Caporicci
#===============================================================================

source(here::here("R", "config", "data_paths.R"))

source(
  here::here(
    "R", "validation", "validate_fact_sales.R"
  )
)

# Load the synthetic dataset
validator_test_paths <- pharmabi_data_paths("demo")

validator_test_source <- readRDS(
  validator_test_paths$fact_file
)

run_validator_case <- function(
    case_name,
    test_data,
    expected_error = NULL
) {

  test_file <- tempfile(fileext = ".rds")
  on.exit(unlink(test_file), add = TRUE)

  saveRDS(test_data, test_file)

  result <- tryCatch(
    {
      validate_fact_sales(test_file)

      list(
        accepted = TRUE,
        message = "Validation accepted"
      )
    },
    error = function(e) {
      list(
        accepted = FALSE,
        message = conditionMessage(e)
      )
    }
  )

  passed <- if (is.null(expected_error)) {
    result$accepted
  } else {
    !result$accepted &&
      grepl(expected_error, result$message, fixed = TRUE)
  }

  data.frame(
    test = case_name,
    status = if (passed) "Passed" else "Failed",
    expected = if (is.null(expected_error)) {
      "Accepted"
    } else {
      expected_error
    },
    observed = result$message,
    stringsAsFactors = FALSE
  )
}

# Clear any previous test summary
validator_test_results <- NULL

# Case 1: duplicate key
validator_case_duplicate <- dplyr::bind_rows(
  validator_test_source,
  validator_test_source[1, ]
)

# Case 2: incorrect profit, with a consistent margin
validator_case_profit <- validator_test_source

stopifnot(validator_case_profit$revenue[1] != 0)

validator_case_profit$profit[1] <-
  validator_case_profit$profit[1] + 1

validator_case_profit$margin[1] <-
  validator_case_profit$profit[1] /
  validator_case_profit$revenue[1]

# Case 3: incorrect margin
validator_case_margin <- validator_test_source

validator_case_margin$margin[1] <-
  validator_case_margin$margin[1] + 0.10

validator_test_results <- do.call(
  rbind,
  list(
    run_validator_case(
      "Valid demo",
      validator_test_source
    ),
    run_validator_case(
      "Duplicate key",
      validator_case_duplicate,
      expected_error = "duplicate_keys"
    ),
    run_validator_case(
      "Incorrect profit",
      validator_case_profit,
      expected_error = "max_profit_difference"
    ),
    run_validator_case(
      "Incorrect margin",
      validator_case_margin,
      expected_error = "max_margin_difference"
    )
  )
)

print(
  validator_test_results[c("test", "status")],
  row.names = FALSE
)

stopifnot(
  all(validator_test_results$status == "Passed")
)

message("All four fact-validator tests passed.")