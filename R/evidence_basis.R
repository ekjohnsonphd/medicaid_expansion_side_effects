# ==============================================================================
# DECISION 1 evidence: age/sex-standardized vs All-ages basis.
#
# Three questions, in the order they should be asked:
#   E1.1  Is the decomposition coherent on each basis?  (denominator recovery)
#   E1.2  Is the demographic objection to All-ages real here?  (age structure)
#   E1.3  How much does standardization move the data at all?
#
# No models. These are facts about the source data.
# ==============================================================================

suppressMessages({library(data.table); library(ggplot2)})
source("~/R/utils/theme_emily.R")

DEX <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"
TOC <- c("AM", "ED", "IP", "NF", "RX")
OUT <- "notes/evidence"

d   <- fread(DEX)[toc %chin% TOC & location_name != "United States" & year_id <= 2018]
coh <- fread("data/medicaid_expansion_cohorts.csv")[, .(location_name, expansion_year)]
cov <- fread("data/state_covariates_2010_2019.csv")
d   <- merge(d, coh, by = "location_name")
d[, grp := fifelse(expansion_year == 2014, "2014 expanders (25)",
            fifelse(expansion_year == 0,   "Never expanded (19)", "Later cohorts (7)"))]

plab <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private", oop = "Out-of-pocket")
blab <- c(`All ages` = "All ages", `Age/sex-standardized` = "Age/sex-standardized")

# --- E1.1 ---------------------------------------------------------------------
# Implied population = spend / spend_per_capita.
#
# There is only one state population. Every payer's ratio must recover the same
# number IF spend_per_capita is a true per-head average (the All-ages case).
# Under standardization it is a weighted rate on a standard age structure, so
# the ratio is not a population and need not agree across payers.
#
# The test: within state-year-TOC, spread of implied population across payers.
d[, implied_pop := spend_mean / spend_per_capita_mean]

sp <- d[is.finite(implied_pop) & implied_pop > 0,
        .(n_payer = .N, spread = max(implied_pop) / min(implied_pop) - 1),
        by = .(age_name, location_name, year_id, toc)][n_payer == 4]

cat("\n=== E1.1  Cross-payer spread in implied population ===\n")
cat("    (0 = all four payers recover the same population)\n\n")
print(sp[, .(`median spread` = sprintf("%.4f%%", 100 * median(spread)),
             `90th pct`      = sprintf("%.4f%%", 100 * quantile(spread, .9)),
             `max`           = sprintf("%.2f%%",  100 * max(spread)),
             `cells > 1%`    = sprintf("%.1f%%", 100 * mean(spread > .01))),
          by = .(Basis = age_name)])

# Does the All-ages implied population match a real population? Compare across
# types of care as well -- same state, same year, five different TOC.
tocsp <- d[age_name == "All ages" & is.finite(implied_pop) & implied_pop > 0,
           .(spread = max(implied_pop) / min(implied_pop) - 1),
           by = .(location_name, year_id)]
cat("\n    All-ages, spread across payers AND types of care within state-year:\n")
cat(sprintf("    median %.6f%%, max %.4f%%\n",
            100 * median(tocsp$spread), 100 * max(tocsp$spread)))

p1 <- ggplot(sp, aes(100 * spread, fill = age_name)) +
  geom_histogram(bins = 60, alpha = .85, colour = NA) +
  facet_wrap(~ age_name, ncol = 1, scales = "free_y") +
  scale_x_continuous("Spread in implied population across the four payers (%)") +
  scale_y_continuous("State-year-setting cells") +
  scale_fill_emily("primary") +
  labs(title = "Only one basis recovers a population",
       subtitle = "Implied population = spending / spending per capita. There is one state population,\nso a coherent per-capita rate must return the same value for every payer.") +
  theme_emily(base_size = 11) + theme(legend.position = "none")
save_fig(p1, file.path(OUT, "E1-1_denominator_coherence.pdf"), size = "double")

# --- E1.2 ---------------------------------------------------------------------
# The objection to All-ages is confounding by demographic composition. That
# objection binds only if the treated and control groups' age structures moved
# APART over the panel. If they moved in parallel, the DiD differences it out.
ac <- merge(cov, coh, by = "location_name")[year_id <= 2018 & expansion_year %in% c(0, 2014)]
ac[, grp := fifelse(expansion_year == 2014, "2014 expanders (25)", "Never expanded (19)")]
am <- melt(ac, id.vars = c("location_name", "year_id", "grp"),
           measure.vars = c("prop_under18", "prop_over65"),
           variable.name = "measure", value.name = "prop")
am[, mlab := c(prop_under18 = "Share under 18", prop_over65 = "Share 65+")[as.character(measure)]]
ag <- am[, .(prop = mean(prop)), by = .(year_id, grp, mlab)]

cat("\n=== E1.2  Did the age structures diverge? ===\n")
gap <- dcast(ag, year_id + mlab ~ grp, value.var = "prop")
setnames(gap, c("2014 expanders (25)", "Never expanded (19)"), c("exp", "nev"))
gap[, gap := 100 * (exp - nev)]
print(gap[year_id %in% c(2010, 2013, 2018), .(mlab, year_id, `gap (pp)` = round(gap, 3))])
cat("\n    Change in the gap, 2010->2018 (pp):\n")
print(gap[, .(`drift` = round(gap[year_id == 2018] - gap[year_id == 2010], 3)), by = mlab])

p2 <- ggplot(ag, aes(year_id, 100 * prop, colour = grp)) +
  geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
  geom_line(linewidth = 1) + geom_point(size = 1.6) +
  facet_wrap(~ mlab, scales = "free_y") +
  scale_x_continuous("", breaks = seq(2010, 2018, 2)) +
  scale_y_continuous("Share of state population (%)") +
  scale_color_emily("primary", name = NULL) +
  labs(title = "Is the demographic objection to All-ages real here?",
       subtitle = "All-ages rates are confounded by age structure only if the groups' structures diverged.\nParallel lines mean the difference-in-differences already removes it.") +
  theme_emily(base_size = 11) + theme(legend.position = "bottom")
save_fig(p2, file.path(OUT, "E1-2_age_structure_divergence.pdf"), size = "double")

# --- E1.3 ---------------------------------------------------------------------
# How much does standardization move the series at all?
tot <- d[expansion_year %in% c(0, 2014),
         .(spc = sum(spend_per_capita_mean)),
         by = .(age_name, location_name, year_id, payer, grp)]
tg <- tot[, .(spc = mean(spc)), by = .(age_name, year_id, payer, grp)]
tg[, plabf := factor(plab[payer], levels = plab)]

p3 <- ggplot(tg, aes(year_id, spc, colour = grp, linetype = age_name)) +
  geom_vline(xintercept = 2013.5, linetype = 3, colour = "grey60") +
  geom_line(linewidth = .85) +
  facet_wrap(~ plabf, scales = "free_y", nrow = 1) +
  scale_x_continuous("", breaks = seq(2010, 2018, 4)) +
  scale_y_continuous("Spending per capita, all five settings ($)") +
  scale_color_emily("primary", name = NULL) +
  scale_linetype_manual(values = c("All ages" = 1, "Age/sex-standardized" = 2), name = NULL) +
  labs(title = "How much does standardization move the data?",
       subtitle = "Group means. Where solid and dashed track each other, the basis is not carrying the result.") +
  theme_emily(base_size = 10) + theme(legend.position = "bottom", legend.box = "vertical")
save_fig(p3, file.path(OUT, "E1-3_basis_overlay.pdf"), size = "double")

cat("\n=== E1.3  Standardized as a share of All-ages, 2018 group means ===\n")
r <- dcast(tg[year_id == 2018], payer + grp ~ age_name, value.var = "spc")
r[, ratio := round(`Age/sex-standardized` / `All ages`, 3)]
print(r[, .(payer, grp, ratio)])

fwrite(sp,  file.path(OUT, "E1-1_implied_pop_spread.csv"))
fwrite(gap, file.path(OUT, "E1-2_age_gap.csv"))
cat("\nFigures written to ", OUT, "\n", sep = "")
