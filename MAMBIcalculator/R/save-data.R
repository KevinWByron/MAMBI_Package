setwd("P:/PartTimers/JoanaPerdomo/Projects/benthic-checkers/MAMBI_Calculator/data")

require(readxl)
# Good-Bad Benchmarks following Pelletier et al. 2018
saline_standards <- read_xlsx("Pelletier2018_Standards.xlsx", sheet = "Saline Sites")
#Good-Bad Benchmarks following Pelletier et al. 2018
tidalFresh_Standards <- read_xlsx("Pelletier2018_Standards.xlsx", sheet = "Tidal Fresh Sites")
# suite of US Ecological Groups assigned initially in Gillett et al. 2015
EG_Ref <- read.csv("Ref - EG Values 2018.csv", stringsAsFactors = F, na.strings = "")

save(saline_standards, file ='saline_standards.Rdata')
save(tidalFresh_Standards, file ='tidalFresh_Standards.Rdata')
save(EG_Ref, file = 'EG_Ref.Rdata')
