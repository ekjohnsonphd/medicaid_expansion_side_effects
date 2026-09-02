# ==============================================================================
# The full information set, with uncertainty.
#
# Counterfactual WITH a confidence band, built from the estimator rather than
# from raw group means:
#     counterfactual_t = actual_t - ATT_t          (ATT_t from the event study)
#     band             = counterfactual_t -/+ 1.96 * SE_t
# The pre-period band is the parallel-trends test drawn in dollars: if the
# actual line sits inside its own counterfactual band before 2014, pre-trends
# are flat. After 2014 a gap outside the band is a significant effect.
# ==============================================================================
source("R/prep_panel.R")
suppressMessages({library(ggplot2); library(did); library(data.table)})
source("~/R/utils/theme_emily.R")
OUT <- "notes/candidates"
p <- prep_panel(verbose = FALSE)
COLA <- "#2166AC"; COLC <- "#6C757D"

# event study + treated-group means, in levels, for one payer/toc/outcome
band <- function(py, tc, out) {
  d <- p[payer == py & toc == tc]
  if (all(!is.finite(d[[out]]))) return(NULL)
  f <- cs_fit(d, out); if (is.null(f) || is.null(f$es)) return(NULL)
  act <- d[expansion_year == 2014, .(actual = mean(get(out))), by = year_id]
  es  <- copy(f$es)[, year_id := event_time + 2014]
  m <- merge(act, es, by = "year_id", all.x = TRUE)
  m[is.na(att), `:=`(att = 0, se = 0)]          # e = -1 is the reference period
  m[, `:=`(cf = actual - att, lo = actual - att - 1.96 * se, hi = actual - att + 1.96 * se,
           payer = py, toc = tc, outcome = out)]
  m[]
}

cfband <- function(d, ylab, title, sub, facet = NULL, ncol = NULL, scales = "free_y") {
  ggplot(d, aes(year_id)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = COLC, alpha = .20) +
    geom_line(aes(y = cf), colour = COLC, linetype = 2, linewidth = .9) +
    geom_line(aes(y = actual), colour = COLA, linewidth = 1.1) +
    geom_point(aes(y = actual), colour = COLA, size = 1.5) +
    scale_x_continuous(NULL, breaks = seq(2010, 2018, 2)) +
    labs(y = ylab, title = title,
         subtitle = paste(strwrap(sub, 95), collapse = "\n")) +
    theme_emily(base_size = 11) +
    { if (!is.null(facet)) facet_wrap(facet, scales = scales, ncol = ncol) }
}

LEG <- "Solid: expansion states' actual path. Dashed with shading: what the estimator says they would have done, with a 95% band. Before 2014 the band is the parallel-trends test."

# ---- C14  Medicaid flagship, with uncertainty --------------------------------
md <- rbind(cbind(band("mdcd", "Total", "spend_per_capita"), m = "Spending per resident"),
            cbind(band("mdcd", "Total", "spend_per_bene"),   m = "Spending per enrollee"))
md[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee"))]
save_fig(cfband(md, "Dollars per year", "C14. Medicaid, with the estimator's uncertainty", LEG, "~ mf"),
         file.path(OUT, "C14_medicaid_band.pdf"), size = "double")

# ---- C15  all four payers, per resident, with uncertainty --------------------
al <- rbindlist(lapply(names(PAYERS), function(x) band(x, "Total", "spend_per_capita")))
al[, mf := factor(PAYERS[payer], levels = PAYERS)]
save_fig(cfband(al, "Dollars per resident per year",
                "C15. Spending per resident, all four payers, with uncertainty",
                paste(LEG, "Out-of-pocket leaves its band before 2014, which is the pre-trend failure."),
                "~ mf", 4),
         file.path(OUT, "C15_all_payers_band.pdf"), size = "double")

# ---- C16  private, both margins, with uncertainty ----------------------------
pv <- rbind(cbind(band("priv", "Total", "spend_per_capita"), m = "Spending per resident"),
            cbind(band("priv", "Total", "spend_per_bene"),   m = "Spending per enrollee"),
            cbind(band("priv", "Total", "vol_per_bene"),     m = "Encounters per enrollee"))
pv[, mf := factor(m, levels = c("Spending per resident", "Spending per enrollee",
                                "Encounters per enrollee"))]
save_fig(cfband(pv, "Level", "C16. Private insurance, three margins, with uncertainty",
                paste(LEG, "The actual path stays inside the band throughout: nothing here is significant."),
                "~ mf", 3),
         file.path(OUT, "C16_private_band.pdf"), size = "double")

# ---- C17  the whole information set: every payer x every setting -------------
gr <- CJ(payer = names(PAYERS), toc = setdiff(names(SETTINGS), "Total"))
allb <- rbindlist(lapply(seq_len(nrow(gr)), function(i)
  band(gr$payer[i], gr$toc[i], "spend_per_capita")))
allb[, `:=`(pf = factor(PAYERS[payer], levels = PAYERS),
            sf = factor(SETTINGS[toc], levels = SETTINGS))]
# facet_grid shares a y-scale across each row, which crushes panels whose
# levels differ; facet_wrap gives each panel its own.
allb[, lab := factor(paste0(pf, "\n", sf),
                     levels = as.vector(outer(SETTINGS[setdiff(names(SETTINGS), "Total")],
                                              PAYERS,
                                              function(a, b) paste0(b, "\n", a))))]
g <- cfband(allb, "Dollars per resident per year",
            "C17. Every payer, every setting: spending per resident",
            paste(LEG, "20 panels, each on its own scale. This is the whole information set for the headline outcome."),
            "~ lab", 4)
ggsave(file.path(OUT, "C17_everything_per_resident.pdf"), g,
       width = 260, height = 300, units = "mm", dpi = 300)
cat("Saved: C17 (260 x 300 mm)\n")
