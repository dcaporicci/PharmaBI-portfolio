#===============================================================================
# PharmaBI
#
# Script: 03_data_cleaning.R
#
# Obiettivo:
# Costruzione del dataset finale per le future analisi.
#
# Autore:
# Danilo Caporicci
#===============================================================================

# Pulizia dei dataset time_slots_2026, categories_gm_2026 e categories_atc_2026
# dai valori NA nella colonna product_desc

sales_clean <- time_slots_2026 %>%
  filter(product_desc != "NA")

categories_gm_clean <- categories_gm_2026 %>%
  filter(!is.na(product_desc))

categories_atc_clean <- categories_atc_2026 %>%
  filter(!is.na(product_desc))


# Verifica se doppio codice atc per prodotto

categories_atc_clean %>%
  group_by(product_code) %>%
  summarise(
    n_atc = n_distinct(atc_code)
  ) %>%
  filter(n_atc > 1)

# Verifica se doppio codice gm per prodotto

categories_gm_clean %>%
  group_by(product_code) %>%
  summarise(
    n_gm = n_distinct(gm_code)
  ) %>%
  filter(n_gm > 1)
