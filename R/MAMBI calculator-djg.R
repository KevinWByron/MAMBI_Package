##########################################################################################################################
## This is a function to calculate multivariate AMBI (M-AMBI) index scores following Pelletier et al. 2018
## which is in turn built upon the work of Sigovini et al. 2013 and Muxica et al. 2007.  The function is
## designed for use in US estuarine waters and requires three arguments:
##          BenthicData_and_path - A quoted string with the name of the xlsx sheet with benthic data to scored.
##                                  The data MUST be in the first tab of the excel file and contain the
##                                  following information with these headings:
##
##                                  StationID - an alpha-numeric identifier of the location (tbl_infaunalabundance_initial)
##                                  Replicate - a numeric identifying the replicate number of samples taken at the
##                                              location (tbl_infaunalabundance_initial)
##                                  SampleDate - the date of sample collection (tbl_infaunalabundance_initial)
##                                  Latitude - latitude in decimal degrees (tbl_grabevent)
##                                  Longitude - longitude in decimal degrees make sure there is a negative sign
##                                              for the Western coordinates (tbl_grabevent)
##                                  Species - name of the fauna, ideally in SCAMIT ed12 format, do not use sp. or spp.,
##                                            use sp only or just the Genus. If no animals were present in the sample
##                                            use NoOrganismsPresent with 0 abundance (tbl_infaunalabundance_initial "taxon")
##                                  Abundance - the number of each Species observed in a sample (tbl_infaunalabundance_initial)
##                                  Salinity - the salinity observed at the location in PSU, ideally at time of sampling
##                                            (comes from tbl_stationoccupation)
##
##          EG_File_Name - A quoted string with the name of the csv file with the suite of US Ecological Groups
##                          assigned initially in Gillett et al. 2015. This EG file has multiple versions of the EG
##                          values and a Yes/No designation if the fauna are Oligochaetes or not. The default file is
##                          the Ref - EG Values 2018.csv file included with this code. Replace with other files as you
##                          see fit, but make sure the file you use is in a similar format and uses the same column names.
##                          Additionally, new taxa can be added at the bottom of the list with the EG values the user
##                          feels appropriate, THOUGH THIS IS NOT RECOMMENDED
##
##          EG_Scheme - A quoted string with the name of the EG Scheme to be used in the AMBI scoring. The default is
##                      Hybrid, though one could use US (all coasts), Standard (Values from Angel Borja and colleagues),
##                      US_East (US East Coast), US_Gulf (US Gulf of Mexico Coast), or US_West (US West Coast).
##
## Two additional files are also needed to run the script: Saline and Tidal freshwater good-bad standards for the M-AMBI
## that are in the Pelletier2018_Standards.xlsx work book and included along with this code.
##
## For the function to run, the following packages NEED to be installed:  tidyverse, reshape2, vegan, and readxl.
## Additionally the EQR.R function must also be installed and is included with this code.
##
## The output of the function will be a dataframe with StationID, Replicate, SampleDate, Latitude, Longitude,
## SalZone (The Salinity Zone assigned by M-AMBI), AMBI_Score, S (Species Richness), H (Species Diversity),
## Oligo_pct (Relative Abundance of Oligochaetes), MAMBI_Score, Orig_MAMBI_Condition, New_MAMBI_Condition,
## Use_MAMBI (Can M-AMBI be applied?), Use_AMBI (Can AMBI be applied?), and YesEG (% of Abundance with a EG value)
##########################################################################################################################


#' Title
#'
#' @param BenthicData_and_path
#' @param EG_File_Name
#' @param EG_Scheme
#'
#' @return
#' @export
#'
#' @examples
#' @importFrom magrittr `%>%`

MAMBI.DJG <- function(BenthicData, EG_DF = RefEGValues2018, EG_Scheme = "Hybrid")
  {
    
    Saline_Standards <- SalineSitesPelletier2018
    TidalFresh_Standards <- TidalFreshSitesPelletier2018
    
    Input_File <- BenthicData %>%
      dplyr::mutate(Species_ended_in_sp = (stringr::str_detect(Species, " sp$")),
                    Taxon = (stringr::str_replace(Species, " sp$", ""))) %>%
      dplyr::mutate(Coast = (ifelse(Longitude <= -115, "West", "Gulf-East"))) %>%
      dplyr::mutate(
        SalZone = dplyr::case_when(
          Salinity > 30 &
            Salinity <= 40 &
            Coast == "Gulf-East" ~ "EH",
          Salinity > 18 &
            Salinity <= 30 &
            Coast == "Gulf-East" ~ "PH",
          Salinity > 5 & Salinity <= 18 ~ "MH",
          Salinity > 0.2 &
            Salinity <= 5 ~ "OH",
          Salinity <= 0.2 ~ "TF",
          Salinity > 40 ~ "HH",
          Salinity > 30 &
            Salinity <= 40 &
            Coast == "West" ~ "WEH",
          Salinity > 18 & Salinity <= 30 & Coast == "West" ~ "WPH"
        )
      )
    
    EG_Ref <- EG_DF %>% 
      dplyr::select(., Taxon, Exclude, EG = EG_Scheme) %>% 
      dplyr::mutate(EG = (ifelse(Taxon == "Oligochaeta", "V", EG)))
    
    total.abundance <- Input_File %>% 
      dplyr::group_by(StationID, Replicate, SampleDate) %>% 
      dplyr::summarise(Tot_abun = sum(Abundance))
    
    Sample.info <- Input_File %>% 
      dplyr::select(StationID, Replicate, SampleDate, Latitude, Longitude,
                    Salinity, Coast, SalZone) %>% 
      unique()
    
    Input_File2 <- Input_File %>% dplyr::filter(!is.na(Salinity))
    
    EG.Assignment <- Input_File %>% 
      dplyr::left_join(., EG_Ref, by = "Taxon") %>% 
      dplyr::left_join(., total.abundance, by = c("StationID", "Replicate", "SampleDate")) %>% 
      dplyr::mutate(Rel_abun = ((Abundance / Tot_abun) * 100))
    EG.Assignment$EG[EG.Assignment$EG == ""] <- NA
    
    AMBI.applicability <- EG.Assignment %>% 
      dplyr::mutate(EG_Test = ifelse(is.na(EG), "NoEG", "YesEG")) %>% 
      reshape2::dcast(., StationID + Replicate + SampleDate ~ EG_Test,
                      value.var = "Rel_abun", fun.aggregate = sum) %>%
      dplyr::mutate(
        Use_AMBI = dplyr::case_when(
          NoEG <= 20 ~ "Yes",
          NoEG > 20 & NoEG <= 50 ~ "With Care",
          NoEG > 50 ~ "Not Recommended",
          is.na(NoEG) ~ "Yes"
        )
      )
    
    MAMBI.applicability <- Sample.info %>% 
      dplyr::mutate(Use_MAMBI = ifelse(is.na(SalZone), "No - No Salinity", "Yes")) %>%
      dplyr::select(StationID, Replicate, SampleDate, Use_MAMBI)
    
    Sal_range.dataset <- unique(Input_File2$SalZone)
    
    
    # ----- Saline calcs ----- 
    
    AMBI.Scores <- EG.Assignment %>% 
      dplyr::group_by(StationID, Replicate, SampleDate, Tot_abun, EG) %>% 
      dplyr::summarise(Sum_Rel = sum(Rel_abun)) %>% 
      tidyr::replace_na(list(EG = "NoEG")) %>%
      dplyr::mutate(
        EG_Score = dplyr::case_when(
          EG == "I" ~ Sum_Rel * 0,
          EG == "II" ~ Sum_Rel * 1.5,
          EG == "III" ~ Sum_Rel * 3,
          EG == "IV" ~ Sum_Rel * 4.5,
          EG == "V" ~ Sum_Rel * 6,
          EG == "NoEG" ~ 0
        )
      ) %>%
      dplyr::mutate(EG_Score = ifelse(Tot_abun == 0, 700, EG_Score)) %>%
      dplyr::group_by(StationID, Replicate, SampleDate) %>% 
      dplyr::summarise(AMBI_Score = (sum(EG_Score) / 100))
    
    Rich <- Input_File %>% 
      dplyr::group_by(StationID, Replicate, SampleDate) %>% 
      dplyr::summarise(S =length(Taxon))
    Rich$S <- as.numeric(Rich$S)
    
    Divy <- Input_File %>% 
      reshape2::dcast(StationID + Replicate + SampleDate ~ Taxon, 
                      value.var = "Abundance", fill = 0) %>%
      dplyr::mutate(H = vegan::diversity((dplyr::select(., 4:(ncol(.)))), 
                                         index = "shannon", base = 2)) %>% 
      dplyr::select(., StationID, Replicate, SampleDate, H)
    
    metrics <- AMBI.Scores %>% 
      dplyr::left_join(., Rich, by = c("StationID", "Replicate", "SampleDate")) %>% 
      dplyr::left_join(., Divy, by = c("StationID", "Replicate", "SampleDate")) %>%
      dplyr::mutate(S = (ifelse(AMBI_Score == 7, 0, S)), 
                    H = (ifelse(AMBI_Score == 7, 0, H)))
    
    metrics.1 <- Sample.info %>% 
      dplyr::left_join(., metrics, by = c("StationID", "Replicate", "SampleDate")) %>%
      dplyr::select(StationID, Replicate, SampleDate, AMBI_Score, S, H, SalZone)
    
    metrics.2 <- dplyr::bind_rows(metrics.1, Saline_Standards)
    
    saline.mambi <- purrr::map_dfr(Sal_range.dataset, function(sal) {
      sal.df <- dplyr::filter(metrics.2, SalZone == sal)
      METRICS.tot <- sal.df[, c(4:6)]
      
      suppressWarnings({
        METRICS.fa2 <- princomp(METRICS.tot, cor = T, covmat = cov(METRICS.tot))
      })
      METRICS.fa2.load <- loadings(METRICS.fa2) %*% diag(METRICS.fa2$sdev)
      METRICS.fa2.load.varimax <- loadings(varimax(METRICS.fa2.load))
      METRICS.scores2 <- scale(METRICS.tot) %*% METRICS.fa2.load.varimax
      colnames(METRICS.scores2) <- c("x", "y", "z")
      METRICS.tr <- METRICS.scores2
      
      eqr <- EQR(METRICS.tr)
      colnames(eqr) <- c("MAMBI_Score")
      eqr <- data.frame(eqr)
      
      results <- sal.df %>% 
        dplyr::bind_cols(., eqr) %>% 
        dplyr::left_join(., Sample.info, by = c("StationID", "Replicate", "SampleDate", "SalZone")) %>%
        dplyr::select(1, 2, 3, 9, 10, 7, 4:6, 8) %>% 
        dplyr::filter(!StationID %in% Saline_Standards$StationID, SalZone != "TF") %>%
        dplyr::mutate(
          Orig_MAMBI_Condition = dplyr::case_when(
            MAMBI_Score < 0.2 ~ "Bad",
            MAMBI_Score >= 0.2 &
              MAMBI_Score < 0.39 ~ "Poor",
            MAMBI_Score >= 0.39 &
              MAMBI_Score < 0.53 ~ "Moderate",
            MAMBI_Score >= 0.53 &
              MAMBI_Score < 0.77 ~ "Good",
            MAMBI_Score >= 0.77 ~ "High"
          ),
          New_MAMBI_Condition = dplyr::case_when(
            MAMBI_Score <= 0.387 ~ "High Disturbance",
            MAMBI_Score > 0.387 &
              MAMBI_Score < 0.483 ~ "Moderate Disturbance",
            MAMBI_Score >= 0.483 &
              MAMBI_Score < 0.578 ~ "Low Disturbance",
            MAMBI_Score >= 0.578 ~ "Reference"
          )
        )
      saline.mambi <- results
    })
    
    #~~~~~~~~~~~~~~~~~~~
    
    if(any(Sal_range.dataset == "TF"))
    {
      TF.EG.Assignment <- EG.Assignment %>% 
        dplyr::filter(SalZone == "TF")
      TF.EG_Ref <- EG_Ref <- EG_DF %>% 
        dplyr::select(., Taxon, Exclude, EG = EG_Scheme, Oligochaeta)
      
      TF.AMBI.Scores <- TF.EG.Assignment %>% 
        dplyr::group_by(StationID, Replicate, SampleDate, Tot_abun, EG) %>% 
        dplyr::summarise(Sum_Rel = sum(Rel_abun)) %>% 
        tidyr::replace_na(list(EG = "NoEG")) %>%
        dplyr::mutate(
          EG_Score = dplyr::case_when(
            EG == "I" ~ Sum_Rel * 0,
            EG == "II" ~ Sum_Rel * 1.5,
            EG == "III" ~ Sum_Rel * 3,
            EG == "IV" ~ Sum_Rel * 4.5,
            EG == "V" ~ Sum_Rel * 6,
            EG == "NoEG" ~ 0
          )
        ) %>%
        dplyr::mutate(EG_Score = ifelse(Tot_abun == 0, 700, EG_Score)) %>%
        dplyr::group_by(StationID, Replicate, SampleDate) %>% 
        dplyr::summarise(AMBI_Score = (sum(EG_Score) / 100))
      
      TF.Oligos <- Input_File %>% 
        dplyr::left_join(., total.abundance, by = c("StationID", "Replicate", "SampleDate")) %>% 
        dplyr::left_join(., TF.EG_Ref, by ="Taxon") %>%
        dplyr::filter(Oligochaeta == "Yes", SalZone == "TF") %>% 
        dplyr::group_by(StationID, Replicate, SampleDate) %>%
        dplyr::summarise(Oligo_pct = (sum(Abundance / Tot_abun)) * 100)
      
      TF.Divy <- Input_File %>% 
        dplyr::filter(SalZone == "TF") %>% 
        reshape2::dcast(StationID + Replicate + SampleDate ~ Taxon,
                        value.var = "Abundance", fill = 0) %>%
        dplyr::mutate(H = vegan::diversity((dplyr::select(., 4:(ncol(.)))), 
                                           index = "shannon", base = 2)) %>% 
        dplyr::select(., StationID, Replicate, SampleDate, H)
      
      
      TF.metrics <- TF.AMBI.Scores %>% 
        dplyr::left_join(., TF.Divy, by = c("StationID", "Replicate", "SampleDate")) %>% 
        dplyr::left_join(., TF.Oligos, by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::mutate(
          Oligo_pct = (ifelse(AMBI_Score == 7, 0, Oligo_pct)),
          H = (ifelse(AMBI_Score == 7, 0, H)),
          Oligo_pct = (ifelse(is.na(Oligo_pct), 0, Oligo_pct))
        )
      
      TF.metrics.1 <- Sample.info %>% 
        dplyr::left_join(., TF.metrics, by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::select(StationID,
               Replicate,
               SampleDate,
               AMBI_Score,
               H,
               Oligo_pct,
               SalZone) %>% 
        dplyr::filter(SalZone == "TF")
      
      TF.metrics.2 <- dplyr::bind_rows(TF.metrics.1, TidalFresh_Standards)
      
      TF.METRICS.tot <- TF.metrics.2[, c(4:6)]
      
      suppressWarnings({
        TF.METRICS.fa2 <- princomp(TF.METRICS.tot, cor = T, covmat = cov(TF.METRICS.tot))
      })
      
      TF.METRICS.fa2.load <- loadings(TF.METRICS.fa2) %*% diag(TF.METRICS.fa2$sdev)
      TF.METRICS.fa2.load.varimax <- loadings(varimax(TF.METRICS.fa2.load))
      TF.METRICS.scores2 <- scale(TF.METRICS.tot) %*% TF.METRICS.fa2.load.varimax
      colnames(TF.METRICS.scores2) <- c("x", "y", "z")
      TF.METRICS.tr <- TF.METRICS.scores2
      
      TF.eqr <- EQR(TF.METRICS.tr)
      colnames(TF.eqr) <- c("MAMBI_Score")
      TF.eqr <- data.frame(TF.eqr)
      
      TF.mambi <- TF.metrics.2 %>% 
        dplyr::bind_cols(., TF.eqr) %>% 
        dplyr::left_join(., Sample.info, by = c("StationID", "Replicate", "SalZone", "SampleDate")) %>%
        dplyr::select(1, 2, 3, 9, 10, 7, 4:6, 8) %>% 
        dplyr::filter(!StationID %in% TidalFresh_Standards$StationID) %>%
        dplyr::mutate(
          Orig_MAMBI_Condition = dplyr::case_when(
            MAMBI_Score < 0.2 ~ "Bad",
            MAMBI_Score >= 0.2 &
              MAMBI_Score < 0.39 ~ "Poor",
            MAMBI_Score >= 0.39 &
              MAMBI_Score < 0.53 ~ "Moderate",
            MAMBI_Score >= 0.53 &
              MAMBI_Score < 0.77 ~ "Good",
            MAMBI_Score >= 0.77 ~ "High"
          ),
          New_MAMBI_Condition = dplyr::case_when(
            MAMBI_Score <= 0.387 ~ "High Disturbance",
            MAMBI_Score > 0.387 &
              MAMBI_Score < 0.483 ~ "Moderate Disturbance",
            MAMBI_Score >= 0.483 &
              MAMBI_Score < 0.578 ~ "Low Disturbance",
            MAMBI_Score >= 0.578 ~ "Reference"
          )
        )
      
      saline.mambi <- saline.mambi %>% 
        dplyr::mutate(Oligo_pct = NA) %>% 
        dplyr::select(1:9, 13, 10, 11, 12)
      
      TF.mambi <- TF.mambi %>% 
        dplyr::mutate(S = NA) %>% 
        dplyr::select(1:7, 13, 8:12)
      
      Overall.Results <-
        dplyr::bind_rows(saline.mambi, TF.mambi) %>% 
        dplyr::left_join(., AMBI.applicability[, c(1, 2, 3, 5, 6)],
                         by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::left_join(MAMBI.applicability, 
                         ., 
                         by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::select(1:3, 5:14, 4, 16, 15)
    } else {
      
      Overall.Results <- saline.mambi %>% 
        dplyr::left_join(., 
                         AMBI.applicability[, c(1, 2, 3, 5, 6)],
                         by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::left_join(MAMBI.applicability,
                         .,
                         by = c("StationID", "Replicate", "SampleDate")) %>%
        dplyr::select(1:3, 5:13, 4, 15, 14)
    }
    
  }
