# Builds the modelling panel with the decomposition components as outcomes.
#
# Denominators are recovered from the DEX ratios:
#   enrollees  = spend_mean / spend_per_bene
#   population = spend_mean / spend_per_capita
# Under "All ages" these are exact; under standardization the implied
# population is not a population (see slides/eda_deck.tex), so the
# decomposition is only coherent on the All-ages basis.

library(data.table)

DEX_TP <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"
TOC_KEEP <- c("AM", "ED", "IP", "NF", "RX")
PANEL_END <- 2018

XF_MAIN <- ~ poverty_rate + inc_k + ave_prior_uninsured + prop_under18 + prop_over65
XF_SENS <- ~ ave_prior_uninsured + inc_k

prep_components <- function(age_basis = "All ages") {
  d   <- fread(DEX_TP)
  coh <- fread("data/medicaid_expansion_cohorts.csv")
  cov <- fread("data/state_covariates_2010_2019.csv")

  x <- d[age_name == age_basis & location_name != "United States" & toc %chin% TOC_KEEP]
  x[, `:=`(bene = spend_mean / spend_per_bene_mean,
           pop  = spend_mean / spend_per_capita_mean)]
  # Volume is derived from the per-capita rate, not the per-enrollee rate, so
  # that out-of-pocket (which has no enrollee denominator) still yields volume
  # and price. The two agree exactly where both are available.
  x[, vol := vol_per_capita_mean / 1000 * pop]

  # Population is payer-invariant; take it from a payer that always has one.
  popref <- x[payer == "mdcd" & toc == "IP", .(location_name, year_id, pop_ref = pop)]
  x <- merge(x, popref, by = c("location_name", "year_id"))

  # Aggregate across the five types of care, plus keep each separately.
  agg <- x[, .(spend = sum(spend_mean), vol = sum(vol),
               bene = bene[toc == "IP"][1], pop_ref = pop_ref[1]),
           by = .(location_name, year_id, payer)][, toc := "Total"]
  ind <- x[, .(location_name, year_id, payer, toc,
               spend = spend_mean, vol = vol, bene = bene, pop_ref = pop_ref)]
  p <- rbind(agg, ind, use.names = TRUE)

  p[, `:=`(spend_per_capita = spend / pop_ref,
           spend_per_bene   = spend / bene,
           vol_per_capita   = vol / pop_ref * 1000,
           vol_per_bene     = vol / bene * 1000,
           spend_per_vol    = spend / vol,
           coverage         = 100 * bene / pop_ref)]

  # All-payer total: does expansion raise total spending or reallocate it?
  # Volume is not summable across payers (units differ by payer mix), so the
  # all-payer row carries spending and coverage-free measures only.
  tot <- p[, .(spend = sum(spend), vol = NA_real_, bene = NA_real_,
               pop_ref = pop_ref[1]), by = .(location_name, year_id, toc)]
  tot[, payer := "all"]
  p <- rbind(p, tot, use.names = TRUE, fill = TRUE)
  p[payer == "all", `:=`(spend_per_capita = spend / pop_ref,
                         spend_per_bene = NA_real_, vol_per_capita = NA_real_,
                         vol_per_bene = NA_real_, spend_per_vol = NA_real_,
                         coverage = NA_real_)]

  p <- merge(p, coh[, .(location_name, expansion_year, restricted)], by = "location_name")
  p <- merge(p, cov, by = c("location_name", "year_id"))
  p[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]), by = location_name]
  p[, inc_k := median_hh_income / 1000]
  p <- p[year_id <= PANEL_END]
  p[, id := as.numeric(as.factor(location_name))]
  p[]
}
