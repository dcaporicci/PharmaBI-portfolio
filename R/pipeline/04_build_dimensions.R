#===============================================================================
# PharmaBI
#
# Script: 04_build_dimensions.R
#
# Obiettivo:
# Costruzione dei dataset dimensioni.
#
# Autore:
# Danilo Caporicci
#===============================================================================

# Creazione del dataset dim_products_atc per futuro join

dim_products_atc <- categories_atc_clean %>%
  arrange(desc(date)) %>%
  group_by(product_code) %>%
  slice(1) %>%
  ungroup()

# Controllo dell'unicità

dim_products_atc %>%
  count(product_code) %>%
  filter(n > 1)

# Creazione del dataset dim_products_gm per futuro join

dim_products_gm <- categories_gm_clean %>%
  arrange(desc(date)) %>%
  group_by(product_code) %>%
  slice(1) %>%
  ungroup()

# Controllo dell'unicità

dim_products_gm %>%
  count(product_code) %>%
  filter(n > 1)