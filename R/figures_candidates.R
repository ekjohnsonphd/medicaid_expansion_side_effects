# ==============================================================================
# Candidate material for the poster. Nothing here is a layout decision --
# these are the pieces Emily chooses from.
#
# House idiom: treated vs control group means over time, expansion marked, so
# the gap is visible rather than abstracted into an effect size.
# ==============================================================================
source("R/prep_panel.R")
suppressMessages({library(ggplot2); library(data.table)})
source("~/R/utils/theme_emily.R")
OUT <- "notes/candidates"
p   <- prep_panel(verbose = FALSE)
eff <- fread("results/toc_effects.csv")
COL <- c("2014 expanders (25)" = "#2166AC", "Never expanded (19)" = "#B2182B")

# group means for any outcome
gm <- function(py, out, tocs = "Total") {
  d <- p[payer == py & toc %chin% tocs & is.finite(get(out)),
         .(v = mean(get(out))), by = .(year_id, grp, toc)]
  d[, idx := 100 * v / v[year_id == 2013], by = .(grp, toc)]
  d[, sf := factor(SETTINGS[toc], levels = SETTINGS)][]
}

# the workhorse two-line plot
wrap <- function(x, n = 95) paste(strwrap(x, n), collapse = "\n")

twoline <- function(d, ylab, title, sub, mode = c("level", "index"),
                    facet = NULL, ncol = NULL, scales = "free_y") {
  mode <- match.arg(mode)
  sub  <- wrap(sub)
  d <- copy(d)[, y := if (mode == "level") v else idx]
  g <- ggplot(d, aes(year_id, y, colour = grp)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
    geom_line(linewidth = 1) + geom_point(size = 1.5) +
    scale_x_continuous(NULL, breaks = seq(2010, 2018, 2)) +
    scale_colour_manual(values = COL, name = NULL) +
    labs(y = ylab, title = title, subtitle = sub) +
    theme_emily(base_size = 11) + theme(legend.position = "bottom")
  if (mode == "index") g <- g + geom_hline(yintercept = 100, colour = "grey85", linewidth = .3)
  if (!is.null(facet)) g <- g + facet_wrap(facet, scales = scales, ncol = ncol)
  g
}

est <- function(py, out, tc = "Total") {
  e <- eff[payer == py & outcome == out & toc == tc]
  sprintf("Estimated effect %+.1f%% of the pre-expansion level (SE %.1f)%s",
          e$pct, e$pct_se, fifelse(e$pre_p < .05, "; pre-trend test FAILS", ""))
}

# ---- C1  coverage, the four series ------------------------------------------
lv <- unique(p[toc == "Total", .(location_name, year_id, payer, grp, coverage, uninsured_rate)])
cv <- lv[!is.na(coverage), .(v = mean(coverage)), by = .(year_id, grp, series = payer)]
un <- unique(lv[, .(location_name, year_id, grp, uninsured_rate)])[
  , .(v = mean(uninsured_rate)), by = .(year_id, grp)][, series := "unins"]
a  <- rbind(cv, un)[series %chin% c("mdcd", "priv", "unins", "mdcr")]
a[, sf := factor(c(mdcd = "Medicaid", priv = "Private", unins = "Uninsured",
                   mdcr = "Medicare")[series],
                 levels = c("Medicaid", "Private", "Uninsured", "Medicare"))]
save_fig(
  ggplot(a, aes(year_id, v, colour = grp)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
    geom_line(linewidth = 1) + geom_point(size = 1.5) +
    facet_wrap(~ sf, scales = "free_y", nrow = 1) +
    scale_x_continuous(NULL, breaks = seq(2010, 2018, 4)) +
    scale_colour_manual(values = COL, name = NULL) +
    labs(y = "Share of population (%)",
         title = "C1. Who got covered, and by whom",
         subtitle = wrap("Expansion states covered the uninsured through Medicaid; control states did it through subsidised private coverage.")) +
    theme_emily(base_size = 10) + theme(legend.position = "bottom"),
  file.path(OUT, "C1_coverage.pdf"), size = "double")

# ---- C2 / C3  the flagship pair, both idioms --------------------------------
md <- rbind(cbind(gm("mdcd", "spend_per_capita"), m = "Spending per resident"),
            cbind(gm("mdcd", "spend_per_bene"),   m = "Spending per enrollee"))
md[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee"))]
sub_md <- "Per resident it diverges at expansion. Per enrollee the lines stay together: the extra spending is people, not intensity."
save_fig(twoline(md, "Dollars per year", "C2. Medicaid: the finding, in levels",
                 sub_md, "level", "~ mf"), file.path(OUT, "C2_medicaid_levels.pdf"), size = "double")
save_fig(twoline(md, "2013 = 100", "C3. Medicaid: the finding, indexed to 2013",
                 sub_md, "index", "~ mf"), file.path(OUT, "C3_medicaid_indexed.pdf"), size = "double")

save_fig(twoline(md, "2013 = 100", "C3b. Medicaid: same figure, one shared scale",
                 "The same two panels on a common axis. A free scale magnifies the noise in a flat series; a shared one shows how much smaller the per-enrollee movement is.",
                 "index", "~ mf", scales = "fixed"),
         file.path(OUT, "C3b_medicaid_indexed_sharedscale.pdf"), size = "double")

# ---- C4  Medicaid per resident by setting -----------------------------------
save_fig(twoline(gm("mdcd", "spend_per_capita", names(SETTINGS)),
                 "2013 = 100", "C4. Medicaid spending per resident, by setting",
                 "Significant in ambulatory, emergency and inpatient. Flat in nursing facility and pharmacy.",
                 "index", "~ sf", 3), file.path(OUT, "C4_medicaid_by_setting.pdf"), size = "double")

# ---- C5  private, the same pair ---------------------------------------------
pv <- rbind(cbind(gm("priv", "spend_per_capita"), m = "Spending per resident"),
            cbind(gm("priv", "spend_per_bene"),   m = "Spending per enrollee"))
pv[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee"))]
save_fig(twoline(pv, "2013 = 100", "C5. Private insurance: per resident and per enrollee",
                 "Per resident, nothing. Per enrollee, a small gap opens -- the control group's pool was diluted by new marketplace enrollees.",
                 "index", "~ mf"), file.path(OUT, "C5_private_pair.pdf"), size = "double")

# ---- C6  private utilisation -------------------------------------------------
pu <- rbind(cbind(gm("priv", "vol_per_bene"),   m = "Encounters per enrollee"),
            cbind(gm("priv", "spend_per_bene"), m = "Spending per enrollee"))
pu[, mf := factor(m, levels = c("Encounters per enrollee", "Spending per enrollee"))]
save_fig(twoline(pu, "2013 = 100", "C6. Private: is it use or price?",
                 "Encounters per enrollee move nearly as much as spending per enrollee, so the gap is utilisation rather than prices.",
                 "index", "~ mf"), file.path(OUT, "C6_private_use_vs_price.pdf"), size = "double")

# ---- C7  the other payers ----------------------------------------------------
op <- rbind(cbind(gm("mdcr", "spend_per_capita"), m = "Medicare"),
            cbind(gm("oop",  "spend_per_capita"), m = "Out-of-pocket"))
op[, mf := factor(m, levels = c("Medicare", "Out-of-pocket"))]
save_fig(twoline(op, "2013 = 100", "C7. Medicare and out-of-pocket",
                 "Medicare tracks almost exactly. Out-of-pocket never had parallel trends -- the lines cross repeatedly before expansion.",
                 "index", "~ mf"), file.path(OUT, "C7_medicare_oop.pdf"), size = "double")

# ---- C8  all four payers, one panel each ------------------------------------
al <- rbindlist(lapply(names(PAYERS), function(x)
  cbind(gm(x, "spend_per_capita"), m = PAYERS[[x]])))
al[, mf := factor(m, levels = PAYERS)]
save_fig(twoline(al, "2013 = 100", "C8. Spending per resident, all four payers",
                 "Only Medicaid separates. The money did not move between the others.",
                 "index", "~ mf", 4) , file.path(OUT, "C8_all_payers.pdf"), size = "double")

cat("candidate figures written to ", OUT, "\n")

# ==============================================================================
# C9 -- the counterfactual idiom.
#
# Indexing each group to its own 2013 shows RATIO growth. The estimator reports
# a LEVEL difference expressed as a share of the treated baseline. When the two
# groups start at different levels those disagree, and for private they disagree
# in sign. This idiom avoids that: plot the treated group's actual path against
# the counterfactual built by applying the control group's LEVEL change to the
# treated group's own 2013 starting point.
#
#   counterfactual_t = treated_2013 + (control_t - control_2013)
#
# The vertical gap is then the difference-in-differences, in dollars, and its
# share of the treated baseline is the estimand. This is the unadjusted 2x2
# version; the tabled estimate additionally adjusts for covariates.
# ==============================================================================
cfd <- function(py, out, tocs = "Total") {
  d <- p[payer == py & toc %chin% tocs & is.finite(get(out)),
         .(v = mean(get(out))), by = .(year_id, grp, toc)]
  w <- dcast(d, year_id + toc ~ grp, value.var = "v")
  setnames(w, c("2014 expanders (25)", "Never expanded (19)"), c("tr", "co"))
  w[, `:=`(tr0 = tr[year_id == 2013], co0 = co[year_id == 2013]), by = toc]
  w[, cf := tr0 + (co - co0)]
  m <- melt(w[, .(year_id, toc, Actual = tr, Counterfactual = cf)],
            id.vars = c("year_id", "toc"), variable.name = "line", value.name = "v")
  m[, sf := factor(SETTINGS[toc], levels = SETTINGS)][]
}

cfplot <- function(d, ylab, title, sub, facet = NULL, ncol = NULL) {
  ggplot(d, aes(year_id, v, colour = line, linetype = line)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
    geom_line(linewidth = 1) + geom_point(size = 1.5) +
    scale_x_continuous(NULL, breaks = seq(2010, 2018, 2)) +
    scale_colour_manual(values = c(Actual = "#2166AC", Counterfactual = "#6C757D"), name = NULL) +
    scale_linetype_manual(values = c(Actual = 1, Counterfactual = 2), name = NULL) +
    labs(y = ylab, title = title, subtitle = wrap(sub)) +
    theme_emily(base_size = 11) + theme(legend.position = "bottom") +
    { if (!is.null(facet)) facet_wrap(facet, scales = "free_y", ncol = ncol) }
}

md9 <- rbind(cbind(cfd("mdcd", "spend_per_capita"), m = "Spending per resident"),
             cbind(cfd("mdcd", "spend_per_bene"),   m = "Spending per enrollee"))
md9[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee"))]
save_fig(cfplot(md9, "Dollars per year", "C9. Medicaid: actual against the counterfactual",
  "Dashed line applies the control group's change to the expanders' own starting level. The vertical gap is the difference-in-differences, in dollars.",
  "~ mf"), file.path(OUT, "C9_medicaid_counterfactual.pdf"), size = "double")

al9 <- rbindlist(lapply(names(PAYERS), function(x)
  cbind(cfd(x, "spend_per_capita"), m = PAYERS[[x]])))
al9[, mf := factor(m, levels = PAYERS)]
save_fig(cfplot(al9, "Dollars per resident per year",
  "C10. Spending per resident against the counterfactual, all four payers",
  "Only Medicaid separates from its counterfactual. Out-of-pocket wanders before expansion, which is why it is not interpreted.",
  "~ mf", 4), file.path(OUT, "C10_all_payers_counterfactual.pdf"), size = "double")

pv9 <- rbind(cbind(cfd("priv", "spend_per_capita"), m = "Spending per resident"),
             cbind(cfd("priv", "spend_per_bene"),   m = "Spending per enrollee"))
pv9[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee"))]
save_fig(cfplot(pv9, "Dollars per year", "C11. Private: actual against the counterfactual",
  "Per resident the actual path sits on its counterfactual. Per enrollee a small gap opens, because the control group's pool grew faster than its spending.",
  "~ mf"), file.path(OUT, "C11_private_counterfactual.pdf"), size = "double")
