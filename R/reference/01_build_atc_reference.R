#===============================================================================
# PharmaBI
#
# Script: 01_build_atc_reference.R
# Objective: Build an ATC reference table from AIFA data
#===============================================================================

library(dplyr)
library(readr)
library(here)

#------------------------------------------------------------------------------
# Download source data
#------------------------------------------------------------------------------

reference_dir <- here("data", "reference")

dir.create(
  reference_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

source_file <- file.path(
  reference_dir,
  paste0("atc_aifa_", Sys.Date(), ".csv")
)

if (!file.exists(source_file)) {
  download.file(
    url = "https://drive.aifa.gov.it/farmaci/atc.csv",
    destfile = source_file,
    mode = "wb"
  )
}

#------------------------------------------------------------------------------
# Import
#------------------------------------------------------------------------------

atc_raw <- read_delim(
  file = source_file,
  delim = ";",
  col_types = cols(.default = col_character()),
  trim_ws = TRUE
)

#------------------------------------------------------------------------------
# Clean and identify ATC levels
#------------------------------------------------------------------------------

atc_clean <- atc_raw |>
  rename(
    atc_code = CODICE_ATC,
    atc_desc = DESCRIZIONE
  ) |>
  mutate(
    atc_code = na_if(toupper(trimws(atc_code)), ""),
    # Correct source typo, verified against the WHO ATC index
    atc_code = if_else(
      atc_code == "JO5AR13",
      "J05AR13",
      atc_code
    ),
    atc_desc = na_if(trimws(atc_desc), ""),
    code_length = nchar(atc_code),
    atc_level = case_when(
      code_length == 1L ~ 1L,
      code_length == 3L ~ 2L,
      code_length == 4L ~ 3L,
      code_length == 5L ~ 4L,
      code_length == 7L ~ 5L,
      TRUE ~ NA_integer_
    )
  )

#------------------------------------------------------------------------------
# Validate and save the reference table
#------------------------------------------------------------------------------

atc_reference <- atc_clean |>
  select(atc_code, atc_desc, atc_level) |>
  distinct() |>
  arrange(atc_level, atc_code)

# Check standard human ATC code structure

atc_pattern <- paste0(
  "^[ABCDGHJLMNPRSV]",
  "([0-9]{2}([A-Z]([A-Z]([0-9]{2})?)?)?)?$"
)

stopifnot(
  !anyNA(atc_reference),
  anyDuplicated(atc_reference$atc_code) == 0L,
  all(grepl(atc_pattern, atc_reference$atc_code))
)

saveRDS(
  atc_reference,
  here("data", "reference", "atc_reference.rds")
)

message("ATC reference validated and saved successfully.")
