## code to prepare `DATASET` dataset goes here

RefEGValues2018 <- read.csv("inst/Ref - EG Values 2018.csv")
usethis::use_data(RefEGValues2018, overwrite = TRUE)

SalineSitesPelletier2018 <- readxl::read_xlsx("inst/Pelletier2018_Standards.xlsx", sheet = "Saline Sites") 
usethis::use_data(SalineSitesPelletier2018, overwrite = TRUE)

TidalFreshSitesPelletier2018 <- readxl::read_xlsx("inst/Pelletier2018_Standards.xlsx", sheet = "Tidal Fresh Sites")
usethis::use_data(TidalFreshSitesPelletier2018, overwrite = TRUE)

