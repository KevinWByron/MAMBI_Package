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
station_occupation <- tbl(con, "tbl_stationoccupation") %>% as_tibble
grab <- tbl(con, "tbl_grabevent") %>% as_tibble


benthic_data <- grab %>% 
  dplyr::filter(benthicinfauna == 'Yes') %>%
  dplyr::inner_join(station_occupation, by = c('stationid','sampledate' = 'occupationdate')) %>%
  dplyr::inner_join(infauna, by = c('stationid','sampledate')) %>%
  dplyr::select('stationid','replicate','sampledate','latitude','longitude','taxon','abundance','salinity') %>%
  dplyr::rename(species = taxon)
  



