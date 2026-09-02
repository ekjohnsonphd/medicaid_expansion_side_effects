# =============================================================================
# E6: does Callaway--Sant'Anna buy anything over plain TWFE here?
#
# With ONE treated cohort (2014) and never-treated controls there are no
# already-treated units to act as controls, so the Goodman-Bacon /
# de Chaisemartin-D'Haultfoeuille / Sun-Abraham negative-weighting problem
# cannot arise. Whatever difference remains is NOT about staggered timing.
# This script measures what is left.
# =============================================================================
source("R/prep_panel.R")
suppressMessages({library(fixest); library(data.table)})
p <- prep_panel(verbose = FALSE)
ov <- fread("notes/evidence/overall_att.csv")

CELLS <- list(
  c("mdcd", "spend_per_capita"), c("mdcd", "spend_per_bene"),
  c("priv", "spend_per_capita"), c("priv", "spend_per_bene"),
  c("mdcr", "spend_per_capita"))

res <- rbindlist(lapply(CELLS, function(k) {
  py <- k[1]; out <- k[2]
  d <- p[payer == py & toc == "Total" & is.finite(get(out))]
  d[, `:=`(treated = as.integer(expansion_year == 2014),
           post    = as.integer(year_id >= 2014))]
  d[, dpost := treated * post]
  base <- d[treated == 1 & year_id <= 2013, mean(get(out))]

  set.seed(20260902L)
  mn <- suppressWarnings(did::att_gt(yname = out, tname = "year_id", idname = "id",
        gname = "expansion_year", data = d, control_group = "nevertreated",
        clustervars = "id", est_method = "reg", xformla = ~ 1,
        bstrap = TRUE, cband = TRUE))
  an <- did::aggte(mn, type = "simple", bstrap = TRUE)
  f0 <- feols(as.formula(paste(out, "~ dpost | id + year_id")), d, cluster = ~ id)
  f1 <- feols(as.formula(paste(out,
        "~ dpost + poverty_rate + inc_k + ave_prior_uninsured + prop_under18 +
           prop_over65 | id + year_id")), d, cluster = ~ id)
  cs <- ov[payer == py & toc == "Total" & outcome == out]

  data.table(payer = py, outcome = out, base = base,
             cs_att = cs$att,          cs_se = cs$se,
             csn_att = an$overall.att, csn_se = an$overall.se,
             tw_att = coef(f0)["dpost"], tw_se = se(f0)["dpost"],
             twx_att = coef(f1)["dpost"], twx_se = se(f1)["dpost"])
}))
res[, `:=`(cs_pct = 100*cs_att/base, csn_pct = 100*csn_att/base,
           csn_pct_se = 100*csn_se/base, tw_pct = 100*tw_att/base,
           twx_pct = 100*twx_att/base,
           cs_pct_se = 100*cs_se/base, tw_pct_se = 100*tw_se/base,
           twx_pct_se = 100*twx_se/base)]

cat("\n== Overall effect, % of pre-2014 level (SE) ==\n")
print(res[, .(payer, outcome,
  CS_X     = sprintf("%+.1f (%.1f)", cs_pct,  cs_pct_se),
  CS_noX   = sprintf("%+.1f (%.1f)", csn_pct, csn_pct_se),
  TWFE_noX = sprintf("%+.1f (%.1f)", tw_pct,  tw_pct_se),
  TWFE_X   = sprintf("%+.1f (%.1f)", twx_pct, twx_pct_se))])
cat("\nCS vs TWFE, same covariate treatment (pp):\n")
print(res[, .(payer, outcome, no_covars = round(csn_pct - tw_pct, 2),
              with_covars = round(cs_pct - twx_pct, 2))])
fwrite(res, "notes/evidence/E6-1_cs_vs_twfe.csv")

# ---- the event-study paths, headline outcome ---------------------------------
d <- p[payer == "mdcd" & toc == "Total"]
d[, treated := as.integer(expansion_year == 2014)]
fe <- feols(spend_per_capita ~ i(year_id, treated, ref = 2013) +
            poverty_rate + inc_k + ave_prior_uninsured + prop_under18 +
            prop_over65 | id + year_id, d, cluster = ~ id)
b <- res[payer == "mdcd" & outcome == "spend_per_capita", base]
cf <- coef(fe)[grepl("^year_id::", names(coef(fe)))]
tw <- data.table(year_id = as.integer(sub("^year_id::([0-9]{4}).*$", "\\1", names(cf))),
                 twfe = 100 * cf / b)
es <- fread("notes/evidence/event_study.csv")[
  payer == "mdcd" & toc == "Total" & outcome == "spend_per_capita"]
es[, `:=`(year_id = event_time + 2014, cs = 100 * att / b)]
cat("\n== Event-study paths, Medicaid spending per resident (% of pre-2014) ==\n")
print(merge(es[, .(year_id, event_time, CS = round(cs, 1))],
            tw[, .(year_id, TWFE = round(twfe, 1))], by = "year_id", all = TRUE))

# ---- what the covariate choice does to the marginal-enrollee number ----------
# per-enrollee % change d implies marginal cost r (as a fraction of an incumbent)
# via  d = 100 * m (r - 1) / (1 + m),  m = enrolment growth.
m <- 0.199
rr <- function(d) 1 + d * (1 + m) / (100 * m)
pe <- res[payer == "mdcd" & outcome == "spend_per_bene"]
cat("\n== Marginal enrollee cost, Medicaid ==\n")
cat(sprintf("with covariates    per-enrollee %+.1f%%  ->  r = %.2f  ($%s of $5,649)\n",
    pe$cs_pct,  rr(pe$cs_pct),  format(round(rr(pe$cs_pct)  * 5649), big.mark = ",")))
cat(sprintf("without covariates per-enrollee %+.1f%%  ->  r = %.2f  ($%s of $5,649)\n",
    pe$csn_pct, rr(pe$csn_pct), format(round(rr(pe$csn_pct) * 5649), big.mark = ",")))
