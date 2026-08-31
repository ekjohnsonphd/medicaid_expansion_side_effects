# ==============================================================================
# Shiny App Deployment Script for shinyapps.io
# ==============================================================================

# Install rsconnect if needed
if (!require("rsconnect")) {
  install.packages("rsconnect")
}
library(rsconnect)

# ==============================================================================
# PASTE YOUR TOKEN INFO HERE (from shinyapps.io -> Account -> Tokens)
# ==============================================================================
# Credentials are read from the environment, never committed.
# Set these in ~/.Renviron:
#   SHINYAPPS_TOKEN=...
#   SHINYAPPS_SECRET=...
rsconnect::setAccountInfo(
  name   = "ekjohnsonphd",
  token  = Sys.getenv("SHINYAPPS_TOKEN"),
  secret = Sys.getenv("SHINYAPPS_SECRET")
)

stopifnot(nzchar(Sys.getenv("SHINYAPPS_TOKEN")), nzchar(Sys.getenv("SHINYAPPS_SECRET")))

# ==============================================================================
# Deploy the app
# ==============================================================================
rsconnect::deployApp(
  appDir = ".",
  appFiles = c(
    "app.R",
    "data/medicaid_expansion_raw_data.csv",
    "data/medicaid_expansion_cohorts.csv",
    "data/state_covariates_2010_2019.csv",
    "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV",
    "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_CAUSE_2010_2019_Y2025M02D13.CSV",
    "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2010_2012_Y2025M02D13.CSV",
    "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2013_2015_Y2025M02D13.CSV",
    "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_CAUSE_2016_2019_Y2025M02D13.CSV"
  ),
  appName = "medicaid-expansion-analysis",
  appTitle = "Medicaid Expansion DiD Analysis",
  forceUpdate = TRUE
)
