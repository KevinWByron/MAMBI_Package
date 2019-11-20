setwd("P:/PartTimers/JoanaPerdomo/MAMBI_Calculator/MAMBIcalculator/data")

require(readxl)
# Good-Bad Benchmarks following Pelletier et al. 2018
Saline_Standards <- read_xlsx("Pelletier2018_Standards.xlsx", sheet = "Saline Sites")
#Good-Bad Benchmarks following Pelletier et al. 2018
TidalFresh_Standards <- read_xlsx("Pelletier2018_Standards.xlsx", sheet = "Tidal Fresh Sites")
# suite of US Ecological Groups assigned initially in Gillett et al. 2015
EG_Ref <- read.csv("Ref - EG Values 2018.csv", stringsAsFactors = F, na.strings = "")

save(Saline_Standards, file ='Saline_Standards.Rdata')
save(TidalFresh_Standards, file ='TidalFresh_Standards.Rdata')
save(EG_Ref, file = 'EG_Ref.Rdata')
