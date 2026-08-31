# ==============================================================================
# Callaway & Sant'Anna (2021) group-time ATTs for Medicaid expansion.
#
# Main spec        : outcome regression ("reg") with the full covariate set.
# Sensitivity spec : doubly robust ("dr") with uninsurance + income only.
#
# The propensity score underlying "dr"/"ipw" cannot support the full covariate
# set at N=51 states -- it separates perfectly and returns NA for most (g,t)
# cells, including within the 2014 cohort on its own. See paper/methods_notes.qmd.
# ==============================================================================

source("R/prep_data.R")
library(did)

dt <- prep_data()

fwrite(dt, "data/analysis/model_data.csv")

SPECS <- list(
  main = list(est = "reg", xformla = XF_MAIN),
  sens = list(est = "dr",  xformla = XF_SENS)
)

# The joint pre-trend Wald test is uninformative on the full staggered sample:
# the thin cohorts (2015 n=3, 2016 n=3, 2017 n=1) contribute pre-period cells whose
# covariance is estimated from almost nothing, so W explodes and the test rejects
# every model including pure placebos. It is only interpretable on the 2014 cohort.
SAMPLES <- list(all_cohorts = function(d) d,
                c2014       = function(d) d[expansion_year %in% c(0, 2014)])

matrix_dt <- CJ(payer   = c("mdcd", "mdcr", "oop", "priv"),
                toc     = c("Total", "AM", "ED", "IP", "NF", "RX"),
                outcome = OUTCOMES,
                spec    = names(SPECS),
                sample  = names(SAMPLES), unique = TRUE)
# Out-of-pocket has no beneficiary denominator.
matrix_dt <- matrix_dt[!(payer == "oop" &
                         outcome %chin% c("spend_per_bene_mean", "vol_per_bene_mean"))]
matrix_dt[, mod := .I]

fit_one <- function(i) {
  row <- matrix_dt[i]
  sp  <- SPECS[[row$spec]]
  sub <- SAMPLES[[row$sample]](dt[payer == row$payer & toc == row$toc])

  m <- try(suppressWarnings(att_gt(
    yname = row$outcome, tname = "year_id", idname = "id", gname = "expansion_year",
    data = sub, control_group = "notyettreated", clustervars = "id",
    est_method = sp$est, xformla = sp$xformla)), silent = TRUE)
  if (inherits(m, "try-error")) return(NULL)

  dyn <- try(suppressWarnings(aggte(m, type = "dynamic")), silent = TRUE)
  ovr <- try(suppressWarnings(aggte(m, type = "simple")), silent = TRUE)
  if (inherits(dyn, "try-error")) return(NULL)

  es <- data.table(mod = row$mod, event_time = dyn$egt,
                   att = dyn$att.egt, se = dyn$se.egt)
  es[, `:=`(lower = att - 1.96 * se, upper = att + 1.96 * se,
            period = fifelse(event_time >= 0, "Post", "Pre"),
            overall_att = if (inherits(ovr, "try-error")) NA_real_ else ovr$overall.att,
            overall_se  = if (inherits(ovr, "try-error")) NA_real_ else ovr$overall.se,
            n_na_cells  = sum(is.na(m$att) | is.na(m$se)),
            pretrend_p  = if (is.null(m$Wpval)) NA_real_ else m$Wpval)]
  es[]
}

message("Fitting ", nrow(matrix_dt), " models...")
res <- rbindlist(lapply(seq_len(nrow(matrix_dt)), fit_one))
res <- merge(matrix_dt, res, by = "mod")

dir.create("results", showWarnings = FALSE)
fwrite(res, "results/event_study_estimates.csv")
fwrite(unique(res[, .(payer, toc, outcome, spec, sample,
                      overall_att, overall_se, n_na_cells, pretrend_p)]),
       "results/overall_att.csv")

failed <- matrix_dt[!mod %in% res$mod]
message("Converged: ", uniqueN(res$mod), " / ", nrow(matrix_dt))
if (nrow(failed)) {
  message("Failed to aggregate:")
  print(failed[, .(payer, toc, outcome, spec)])
}
