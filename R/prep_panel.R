# ==============================================================================
# The analysis panel. All-ages basis (Decision 1, confirmed 2026-09-02).
#
# Denominators are recovered from the DEX ratios and are exact on this basis:
#   pop  = spend / spend_per_capita      (state population; payer-invariant)
#   bene = spend / spend_per_bene        (payer enrollees, PER SETTING)
#
# The enrollee denominator is NOT common across settings. It is ~1% apart for
# Medicaid, but Medicare's pharmacy denominator is Part D enrollment -- 13.9% of
# population against 17.9% for inpatient, a 40% gap. Private is ~4% apart for
# the same reason (drug coverage is a subset of medical coverage). So:
#   - setting-specific per-enrollee outcomes use that setting's own denominator;
#   - the Total and the coverage outcome use INPATIENT enrollment as the
#     reference for core coverage. That reference reproduces external benchmarks
#     (2018 medians: Medicaid 20.0%, Medicare 17.9%, private 65.2%).
#
# Sample: 2014 cohort (25 states) vs never-expanded (19). 2010-2018.
# Later cohorts (MI, NH, PA, IN, AK, MT, LA) are excluded: at 3, 3 and 1 states
# the estimator's variance is not identified. See notes/audit.md.
# ==============================================================================

suppressMessages(library(data.table))

DEX <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"
TOC <- c("AM", "ED", "IP", "NF", "RX")
XF  <- ~ poverty_rate + inc_k + ave_prior_uninsured + prop_under18 + prop_over65

PAYERS <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private", oop = "Out-of-pocket")
SETTINGS <- c(Total = "All care", AM = "Ambulatory", ED = "Emergency",
              IP = "Inpatient", NF = "Nursing facility", RX = "Pharmacy")

prep_panel <- function(verbose = TRUE) {
  d <- fread(DEX)[age_name == "All ages" & toc %chin% TOC &
                  location_name != "United States" & year_id <= 2018]

  d[, `:=`(pop  = spend_mean / spend_per_capita_mean,
           bene = spend_mean / spend_per_bene_mean)]
  # Volume: DEX reports encounters per 1,000. Recover the count so it can be
  # aggregated, then re-express per capita and per enrollee below.
  d[, vol := vol_per_capita_mean / 1000 * pop]

  if (verbose) {
    # Both denominators should be invariant where theory says they are.
    pv <- d[, .(sp = max(pop) / min(pop) - 1), by = .(location_name, year_id)]
    message(sprintf("  population, spread across payers x TOC : median %.5f%%, max %.4f%%",
                    100 * median(pv$sp), 100 * max(pv$sp)))
  }

  # Population is payer-invariant; take one reference series.
  popref <- d[payer == "mdcd" & toc == "IP", .(location_name, year_id, pop_ref = pop)]
  # Core coverage reference: inpatient enrollment (see header).
  beneref <- d[toc == "IP" & is.finite(bene) & bene > 0,
               .(location_name, year_id, payer, bene_ip = bene)]

  # Totals across the five settings, plus each setting on its own.
  # NOTE: Total volume sums encounters across settings, which adds a hospital
  # stay to a prescription fill. Usable as "total encounters", not as a
  # quantity with a natural unit. Per-setting volume is the interpretable one.
  tot <- d[, .(spend = sum(spend_mean), vol = sum(vol), bene = NA_real_, toc = "Total"),
           by = .(location_name, year_id, payer)]
  ind <- d[, .(location_name, year_id, payer, toc, spend = spend_mean,
               vol = vol, bene = bene)]
  p <- rbind(tot, ind, use.names = TRUE)

  p <- merge(merge(p, popref,  by = c("location_name", "year_id")),
             beneref, by = c("location_name", "year_id", "payer"), all.x = TRUE)

  # Per-enrollee: own-setting denominator, except Total which uses the reference.
  p[, bene_use := fifelse(toc == "Total", bene_ip, bene)]

  p[, `:=`(vol_per_capita = 1000 * vol / pop_ref,
           vol_per_bene    = fifelse(is.finite(bene_use) & bene_use > 0,
                                     1000 * vol / bene_use, NA_real_),
           spend_per_capita = spend / pop_ref,
           spend_per_bene   = fifelse(is.finite(bene_use) & bene_use > 0,
                                      spend / bene_use, NA_real_),
           coverage         = fifelse(is.finite(bene_ip) & bene_ip > 0,
                                      100 * bene_ip / pop_ref, NA_real_))]

  coh <- fread("data/medicaid_expansion_cohorts.csv")[, .(location_name, expansion_year, restricted)]
  cov <- fread("data/state_covariates_2010_2019.csv")
  p <- merge(merge(p, coh, by = "location_name"), cov, by = c("location_name", "year_id"))
  p <- p[expansion_year %in% c(0, 2014)]

  p[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]),
    by = location_name]
  p[, `:=`(inc_k = median_hh_income / 1000,
           id    = as.integer(factor(location_name)),
           grp   = fifelse(expansion_year == 2014, "2014 expanders (25)", "Never expanded (19)"))]
  p[]
}

# One Callaway-Sant'Anna fit; returns overall ATT, event study, and pre-test.
cs_fit <- function(d, yname, bstrap = TRUE) {
  if (all(!is.finite(d[[yname]]))) return(NULL)
  m <- try(suppressWarnings(did::att_gt(
    yname = yname, tname = "year_id", idname = "id", gname = "expansion_year",
    data = d, control_group = "nevertreated", clustervars = "id",
    est_method = "reg", xformla = XF, bstrap = bstrap, cband = bstrap)), silent = TRUE)
  if (inherits(m, "try-error")) return(NULL)
  ov <- try(suppressWarnings(did::aggte(m, type = "simple", bstrap = bstrap)), silent = TRUE)
  dy <- try(suppressWarnings(did::aggte(m, type = "dynamic", bstrap = bstrap)), silent = TRUE)
  if (inherits(ov, "try-error")) return(NULL)
  list(overall = data.table(att = ov$overall.att, se = ov$overall.se,
                            pre_p = if (is.null(m$Wpval)) NA_real_ else as.numeric(m$Wpval)[1],
                            base  = d[expansion_year == 2014 & year_id <= 2013,
                                      mean(get(yname), na.rm = TRUE)]),
       es = if (inherits(dy, "try-error")) NULL
            else data.table(event_time = dy$egt, att = dy$att.egt, se = dy$se.egt))
}
