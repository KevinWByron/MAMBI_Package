library(DBI) # needed to connect to database
library(dbplyr) # needed to connect to database
library(RPostgreSQL) # needed to connect to our database
library(rstudioapi) # just so we can type the password as we run the script, so it is not written in the clear
library(tidyverse)

# con is short for connection
# Create connection to the database
con <- DBI::dbConnect(
  PostgreSQL(),
  host = "192.168.1.16",
  dbname = 'bight2018',
  user = 'b18read',
  password = '1969$Harbor' # if we post to github, we might want to do rstudioapi::askForPassword()
)

# Bring in our tables from the database
infauna <- tbl(con, "tbl_infaunalabundance_initial") %>% as_tibble

grab <- tbl(con, "tbl_grabevent") %>%
  as_tibble %>%
  dplyr::filter(grabeventnumber == 1)

assignment <- tbl(con, "field_assignment_table") %>%
  as_tibble %>%
  dplyr::filter(stratum == "Bays" | stratum == "Ports" | stratum == "Estuaries" | stratum == "Brackish Estuaries")

station_occupation <- tbl(con, "tbl_stationoccupation") %>%
  as_tibble %>%
  inner_join(assignment, by = 'stationid')

benthic_data <- grab %>%
  dplyr::filter(benthicinfauna == 'Yes') %>%
  dplyr::inner_join(station_occupation, by = c('stationid','sampledate' = 'occupationdate')) %>%
  dplyr::inner_join(infauna, by = c('stationid','sampledate')) %>%
  dplyr::select('stationid','replicate','sampledate','latitude','longitude','taxon','abundance','salinity') %>%
  dplyr::mutate_if(is.numeric, list(~na_if(., -88))) %>%
  dplyr::rename(species = taxon) %>%
  dplyr::rename(StationID = stationid, Replicate = replicate, SampleDate = sampledate, Latitude = latitude, Longitude = longitude, Species = species, Abundance = abundance, Salinity = salinity)

#mutate(EG_Test=ifelse(is.na(EG),"NoEG", "YesEG"))

save(benthic_data, file = "data/benthic_data.RData")
write.csv(benthic_data, file = "data/benthic_data.csv", row.names = FALSE)

