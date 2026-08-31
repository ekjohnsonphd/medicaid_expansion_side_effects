# Shared data preparation for the Medicaid expansion analysis.
# Sourced by expansion_CSA.R and expansion_SA.R so the two cannot drift apart.

library(data.table)

TOC_INCLUDED <- c("AM", "ED", "IP", "NF", "RX")
PANEL_END    <- 2018   # 2019 expanders (ME, VA) are censored; see paper/methods_notes.qmd
DEX_FILE     <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"

# Main spec: outcome regression, full covariate set.
# Sensitivity: doubly robust, restricted covariates. The propensity score cannot
# support more than two non-collinear covariates at N=51 states (see methods notes).
XF_MAIN <- ~ poverty_rate + inc_k + ave_prior_uninsured + prop_under18 + prop_over65
XF_SENS <- ~ ave_prior_uninsured + inc_k

KEY_COLS   <- c("location_name", "year_id", "payer", "toc", "expansion_year", "restricted")
COVAR_COLS <- c("poverty_rate", "inc_k", "ave_prior_uninsured", "prop_under18", "prop_over65")
OUTCOMES   <- c("spend_per_capita_mean", "spend_per_bene_mean",
                "vol_per_capita_mean", "vol_per_bene_mean", "spend_per_vol_mean")

prep_data <- function(dex_file = DEX_FILE) {
  dt  <- fread(dex_file)
  coh <- fread("data/medicaid_expansion_cohorts.csv")
  cov <- fread("data/state_covariates_2010_2019.csv")

  dt <- dt[age_name == "Age/sex-standardized" & toc %in% TOC_INCLUDED]
  dt <- merge(dt, coh[, .(location_name, expansion_year, restricted)],
              by = "location_name", all.x = TRUE)
  dt <- merge(dt, cov, by = c("location_name", "year_id"))

  dt[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]),
     by = location_name]
  dt[, inc_k := median_hh_income / 1000]
  dt <- dt[year_id <= PANEL_END]

  dt <- dt[, c(KEY_COLS, COVAR_COLS, OUTCOMES), with = FALSE]

  rbind(dt, aggregate_toc(dt))[
    , `:=`(id       = as.numeric(as.factor(location_name)),
           expanded = fifelse(expansion_year != 0 & year_id >= expansion_year, 1L, 0L))][]
}

# Aggregate across types of care.
#
# Per-capita and per-beneficiary outcomes are additive: within a payer the DEX
# denominators are common across TOC (verified: implied beneficiary counts agree
# to <1% across TOC within a state-year-payer), and the per-capita figures are
# age/sex-standardized rates on a shared standard population.
#
# spend_per_vol_mean is a unit price and must NOT be summed -- adding a price per
# prescription to a price per nursing facility stay is meaningless. It is instead
# rebuilt as total spending over total volume.
aggregate_toc <- function(dt) {
  keys <- c(setdiff(KEY_COLS, "toc"), COVAR_COLS)
  add  <- setdiff(OUTCOMES, "spend_per_vol_mean")

  agg <- dt[, lapply(.SD, sum), by = keys, .SDcols = add]
  agg[, spend_per_vol_mean := spend_per_capita_mean / vol_per_capita_mean]
  agg[, toc := "Total"]
  agg[]
}
