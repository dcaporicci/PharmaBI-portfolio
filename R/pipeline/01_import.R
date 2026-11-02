#===============================================================================
# PharmaBI
#
# Script: 01_import.R
#
# Obiettivo:
# Importare i dati esportati dal gestionale della parafarmacia.
#
# Autore:
# Danilo Caporicci
#===============================================================================


#------------------------------------------------------------------------------
# Librerie
#------------------------------------------------------------------------------

library(tidyverse)
library(janitor)
library(lubridate)
library(here)


#------------------------------------------------------------------------------
# Importazione dati
#------------------------------------------------------------------------------

message("Importazione file...")

articles_2026 <-
  read_csv2(
    here(
      "data",
      "raw",
      "sales",
      "articles_2026-01-01_2026-07-14-ITA.csv"
    )
  )

categories_atc_2026 <-
  read_csv2(
    here(
      "data",
      "raw",
      "sales",
      "categories_ATC_2026-01-01_2026-07-14-ITA.csv"
    )
  )

categories_gm_2026 <-
  read_csv2(
    here(
      "data",
      "raw",
      "sales",
      "categories_GM_2026-01-01_2026-07-14-ITA.csv"
    )
  )

time_slots_2026 <-
  read_csv2(
    here(
      "data",
      "raw",
      "sales",
      "time_slots_2026-01-01_2026-07-14-ITA.csv"
    )
  )

message("✓ Importazione completata")
