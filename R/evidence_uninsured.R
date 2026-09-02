# Finding 1: the full coverage accounting, including the uninsured.
#
# NOTE ON SOURCES. The payer coverage measures are DEX-derived (enrollees
# recovered from the spending ratios). The uninsured rate is CPS, from
# data/state_covariates_2010_2019.csv. Different instruments, so the four
# effects are not required to sum to zero and should not be presented as if
# they were an exhaustive partition.
source("R/prep_panel.R")
suppressMessages(library(did))

p <- prep_panel(verbose = FALSE)
u <- unique(p[toc == "Total" & payer == "mdcd",
              .(location_name, year_id, id, expansion_year, grp,
                uninsured_rate, poverty_rate, inc_k, ave_prior_uninsured,
                prop_under18, prop_over65)])

f <- cs_fit(u, "uninsured_rate")
cat("\n=== Effect on the uninsured rate (CPS, percentage points) ===\n")
cat(sprintf("  ATT %+.2f pp (SE %.2f)   pre-trend p = %.3f   pre-period level %.1f%%\n",
            f$overall$att, f$overall$se, f$overall$pre_p, f$overall$base))
cat(sprintf("  95%% CI [%+.2f, %+.2f]\n",
            f$overall$att - 1.96 * f$overall$se, f$overall$att + 1.96 * f$overall$se))

cat("\n=== Coverage accounting ===\n")
ov <- fread("notes/evidence/overall_att.csv")[outcome == "coverage"]
acc <- rbind(ov[, .(measure = PAYERS[payer], att, se, source = "DEX")],
             data.table(measure = "Uninsured", att = f$overall$att,
                        se = f$overall$se, source = "CPS"))
print(acc[, .(measure, `effect (pp)` = round(att, 2), se = round(se, 2), source)])
cat(sprintf("\n  Medicaid gain             : %+.2f pp\n", ov[payer == "mdcd", att]))
cat(sprintf("  Private loss              : %+.2f pp  (%.0f%% of the Medicaid gain)\n",
            ov[payer == "priv", att], 100 * abs(ov[payer == "priv", att]) / ov[payer == "mdcd", att]))
cat(sprintf("  Uninsured change          : %+.2f pp  (%.0f%% of the Medicaid gain)\n",
            f$overall$att, 100 * abs(f$overall$att) / ov[payer == "mdcd", att]))

es <- f$es
fwrite(rbind(fread("notes/evidence/overall_att.csv"),
             cbind(data.table(outcome = "uninsured", payer = "unins", toc = "Total"),
                   f$overall)[, `:=`(pct = 100 * att / base, pct_se = 100 * se / base,
                                     t = att / se, p = 2 * pnorm(-abs(att / se)))],
             fill = TRUE), "notes/evidence/overall_att.csv")
fwrite(cbind(data.table(outcome = "uninsured", payer = "unins", toc = "Total"), es),
       "notes/evidence/event_study_uninsured.csv")
