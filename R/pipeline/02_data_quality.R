#===============================================================================
# PharmaBI
#
# Script: 02_data_quality.R
#
# Obiettivo:
# Capire come sono fatti i dati della parafarmacia.
#
# Autore:
# Danilo Caporicci
#===============================================================================

# Dimensioni

dim(articles_2026)
dim(categories_atc_2026)
dim(categories_gm_2026)
dim(time_slots_2026)

# Struttura

glimpse(articles_2026)
glimpse(categories_atc_2026)
glimpse(categories_gm_2026)
glimpse(time_slots_2026)

# Statistiche

summary(articles_2026)
summary(categories_atc_2026)
summary(categories_gm_2026)
summary(time_slots_2026)

# Controllo valori mancanti

colSums(is.na(articles_2026))
colSums(is.na(categories_atc_2026))
colSums(is.na(categories_gm_2026))
colSums(is.na(time_slots_2026))

# Controllo duplicati

nrow(articles_2026)
nrow(distinct(articles_2026))

nrow(categories_atc_2026)
nrow(distinct(categories_atc_2026))

nrow(categories_gm_2026)
nrow(distinct(categories_gm_2026))

nrow(time_slots_2026)
nrow(distinct(time_slots_2026))

# Controllo dei prodotti presenti in una tabella ma non nell'altra

Prodotti_senza_atc <- time_slots_2026 |>
  anti_join(categories_atc_2026, by = "product_code")

Prodotti_senza_gm <- (time_slots_2026 |>
                        anti_join(categories_gm_2026, by = "product_code"))

# Controllo della chiave logica di times_slots

time_slots_2026 %>%
  count(sale_id, product_code) %>%
  filter(n > 1)
