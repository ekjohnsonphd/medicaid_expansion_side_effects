# ==============================================================================
# DECISION 1 evidence, model half (E1.4, E1.5).
#
# Estimate the SAME primary specification on both age bases and compare.
#   Sample    : 2014 cohort (25 states) vs never-expanded (19). 2010-2018.
#   Outcome   : spending per capita, by payer x {Total + 5 settings}.
#   Estimator : Callaway-Sant'Anna, est_method = "reg", never-treated controls,
#               covariates = poverty, income, prior uninsurance, age structure.
#
# 4 payers x 6 settings x 2 bases = 48 models.
# ==============================================================================

suppressMessages({library(data.table); library(did)})

DEX <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"
TOC <- c("AM", "ED", "IP", "NF", "RX")
XF  <- ~ poverty_rate + inc_k + ave_prior_uninsured + prop_under18 + prop_over65

raw <- fread(DEX)[toc %chin% TOC & location_name != "United States" & year_id <= 2018]
coh <- fread("data/medicaid_expansion_cohorts.csv")[, .(location_name, expansion_year)]
cov <- fread("data/state_covariates_2010_2019.csv")

panel <- function(basis) {
  d <- raw[age_name == basis, .(location_name, year_id, payer, toc,
                                y = spend_per_capita_mean)]
  # Total = sum of the five settings. Per-capita rates share a denominator
  # within a basis, so they are additive.
  d <- rbind(d, d[, .(toc = "Total", y = sum(y)),
                  by = .(location_name, year_id, payer)], use.names = TRUE)
  d <- merge(merge(d, coh, by = "location_name"), cov,
             by = c("location_name", "year_id"))
  d <- d[expansion_year %in% c(0, 2014)]
  d[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]),
    by = location_name]
  d[, `:=`(inc_k = median_hh_income / 1000,
           id    = as.integer(factor(location_name)))][]
}

fit <- function(d, py, tc) {
  s <- d[payer == py & toc == tc]
  if (uniqueN(s$location_name) < 40) return(NULL)
  m <- try(suppressWarnings(att_gt(
    yname = "y", tname = "year_id", idname = "id", gname = "expansion_year",
    data = s, control_group = "nevertreated", clustervars = "id",
    est_method = "reg", xformla = XF)), silent = TRUE)
  if (inherits(m, "try-error")) return(NULL)
  ov <- try(suppressWarnings(aggte(m, type = "simple")), silent = TRUE)
  if (inherits(ov, "try-error")) return(NULL)
  data.table(payer = py, toc = tc,
             att = ov$overall.att, se = ov$overall.se,
             pre_p = if (is.null(m$Wpval)) NA_real_ else as.numeric(m$Wpval)[1],
             # baseline: treated-group mean over the pre-period
             base = s[expansion_year == 2014 & year_id <= 2013, mean(y)])
}

grid <- CJ(payer = c("mdcd", "mdcr", "priv", "oop"),
           toc   = c("Total", "AM", "ED", "IP", "NF", "RX"), unique = TRUE)

res <- rbindlist(lapply(c("All ages", "Age/sex-standardized"), function(b) {
  d <- panel(b)
  message("fitting ", nrow(grid), " models on basis: ", b)
  r <- rbindlist(Map(function(p, t) fit(d, p, t), grid$payer, grid$toc))
  r[, basis := b][]
}))

res[, `:=`(pct = 100 * att / base, pct_se = 100 * se / base)]
res[, sig := fifelse(abs(att / se) > 1.96, "yes", "no")]
fwrite(res, "notes/evidence/E1-4_att_by_basis.csv")

cat("\n=== E1.4  Overall ATT on spending per capita, both bases ===\n")
cat("    (% of the treated group's own pre-2014 level)\n\n")
w <- dcast(res, payer + toc ~ basis, value.var = c("pct", "pct_se", "pre_p"))
setnames(w, gsub("Age/sex-standardized", "std", gsub("All ages", "all", names(w))))
print(w[, .(payer, toc,
            allages = sprintf("%6.1f (%4.1f)", pct_all, pct_se_all),
            stdized = sprintf("%6.1f (%4.1f)", pct_std, pct_se_std),
            diff    = sprintf("%5.1f", pct_all - pct_std))], nrows = 30)

cat("\n=== Agreement between the two bases ===\n")
ok <- w[is.finite(pct_all) & is.finite(pct_std)]
cat(sprintf("  correlation of ATT (%% of baseline) : %.3f\n", cor(ok$pct_all, ok$pct_std)))
cat(sprintf("  same sign                          : %d of %d\n",
            sum(sign(ok$pct_all) == sign(ok$pct_std)), nrow(ok)))
sg <- dcast(res, payer + toc ~ basis, value.var = "sig")
setnames(sg, c("Age/sex-standardized", "All ages"), c("std", "all"))
cat(sprintf("  same significance verdict at 5%%    : %d of %d\n",
            sum(sg$std == sg$all), nrow(sg)))
cat("\n  Cells where the verdict differs:\n")
print(sg[std != all])

cat("\n=== E1.5  Pre-trend pass rate (p >= 0.05) by basis ===\n")
print(res[, .(models = .N,
              pass   = sum(pre_p >= .05, na.rm = TRUE),
              `pass %` = round(100 * mean(pre_p >= .05, na.rm = TRUE))),
          by = .(basis)])
cat("\n  by payer:\n")
print(dcast(res[, .(pass = round(100 * mean(pre_p >= .05, na.rm = TRUE))),
                by = .(basis, payer)], payer ~ basis, value.var = "pass"))

# --- E1.4 figure --------------------------------------------------------------
suppressMessages(library(ggplot2)); source("~/R/utils/theme_emily.R")
plab <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private", oop = "Out-of-pocket")
sc <- dcast(res, payer + toc ~ basis, value.var = "pct")
setnames(sc, c("All ages", "Age/sex-standardized"), c("all", "std"))
sc <- merge(sc, dcast(res, payer + toc ~ basis, value.var = "pct_se")[
  , .(payer, toc, se_all = `All ages`, se_std = `Age/sex-standardized`)],
  by = c("payer", "toc"))
sc[, pf := factor(plab[payer], levels = plab)]

lim <- range(c(sc$all - sc$se_all, sc$all + sc$se_all,
               sc$std - sc$se_std, sc$std + sc$se_std))
p4 <- ggplot(sc, aes(std, all, colour = pf)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey55", linetype = 2) +
  geom_hline(yintercept = 0, colour = "grey85", linewidth = .3) +
  geom_vline(xintercept = 0, colour = "grey85", linewidth = .3) +
  geom_errorbar(aes(ymin = all - se_all, ymax = all + se_all), width = 0, alpha = .35) +
  geom_errorbarh(aes(xmin = std - se_std, xmax = std + se_std), height = 0, alpha = .35) +
  geom_point(size = 2.4) +
  coord_equal(xlim = lim, ylim = lim) +
  scale_color_emily("primary", name = NULL) +
  labs(x = "Age/sex-standardized basis", y = "All-ages basis",
       title = "The age basis does not change the answer",
       subtitle = sprintf("ATT on spending per capita, %% of pre-2014 level.\n24 payer-by-setting cells, one specification.\nCorrelation %.3f. Bars are +/- 1 SE.",
                          cor(sc$all, sc$std))) +
  theme_emily(base_size = 11) + theme(legend.position = "bottom")
save_fig(p4, "notes/evidence/E1-4_att_scatter_by_basis.pdf", size = "double")
