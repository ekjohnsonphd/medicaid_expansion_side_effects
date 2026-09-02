# ==============================================================================
# Poster assets, in two styles.
#
#   banded : treated actual vs event-study counterfactual with a 95% band
#   lines  : treated and control group means -- the plot a health economist
#            expects to see
#
# Out-of-pocket is excluded throughout: DEX defines it as insured cost-sharing
# plus all spending by the uninsured, and expansion moves that mix.
# Total encounters per enrollee is excluded: it sums hospital stays with
# prescription fills.
# ==============================================================================
source("R/prep_panel.R")
suppressMessages({library(ggplot2); library(did); library(data.table)})
source("~/R/utils/theme_emily.R")
FIG <- "poster/figures"; TAB <- "poster/tables"
p <- prep_panel(verbose = FALSE)
eff <- fread("results/toc_effects.csv")

TREAT <- "#00706A"; CTRL <- "#C77D0A"; CF <- "#6C757D"
PAY3  <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private")
BASE  <- 26   # poster type size

th <- function(...) theme_emily(base_size = BASE, ...) +
  theme(legend.position = "bottom",
        legend.text  = element_text(size = BASE - 3),
        axis.text    = element_text(size = BASE - 5),
        axis.title.y = element_text(size = BASE - 3),
        plot.title = element_blank(), plot.subtitle = element_blank(),
        strip.text = element_text(size = BASE - 4, face = "bold"))

# Three ticks only. At A0 the panels are narrow enough that a tick every two
# years runs the labels together.
YRS <- scale_x_continuous(NULL, breaks = c(2010, 2014, 2018))

# PNG only: Typst cannot embed PDF images.
sv <- function(g, f, w = 245, h = 150)
  ggsave(file.path(FIG, sub("\\.pdf$", ".png", f)), g, width = w, height = h,
         units = "mm", dpi = 300, device = ragg::agg_png)

# Copy one idiom's figures to the canonical names the .qmd references, so the
# poster text lives in a single file and switching style is one command:
#   Rscript -e 'source("R/poster_assets.R"); use_style("lines")'
use_style <- function(style = c("lines", "band")) {
  style <- match.arg(style)
  for (n in c("f2_medicaid", "f3_private", "f4_payers"))
    file.copy(file.path(FIG, sprintf("%s_%s.png", n, style)),
              file.path(FIG, sprintf("%s.png", n)), overwrite = TRUE)
  writeLines(style, file.path(FIG, "STYLE"))
  message("poster figures set to: ", style)
}

# ---------- data helpers ------------------------------------------------------
means <- function(py, out, tc = "Total") {
  p[payer == py & toc == tc & is.finite(get(out)),
    .(v = mean(get(out))), by = .(year_id, grp)]
}
band <- function(py, out, tc = "Total") {
  d <- p[payer == py & toc == tc]
  f <- cs_fit(d, out)
  act <- d[expansion_year == 2014, .(actual = mean(get(out))), by = year_id]
  es <- copy(f$es)[, year_id := event_time + 2014]
  m <- merge(act, es, by = "year_id", all.x = TRUE)
  m[is.na(att), `:=`(att = 0, se = 0)]
  m[, `:=`(cf = actual - att, lo = actual - att - 1.96 * se,
           hi = actual - att + 1.96 * se)][]
}

# ---------- the two idioms ----------------------------------------------------
gline <- function(d, ylab) {
  ggplot(d, aes(year_id, v, colour = grp)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55", linewidth = .8) +
    geom_line(linewidth = 1.8) + geom_point(size = 3.4) +
    YRS +
    scale_colour_manual(values = c("2014 expanders (25)" = TREAT,
                                   "Never expanded (19)" = CTRL), name = NULL) +
    labs(y = ylab) + th()
}
gband <- function(d, ylab) {
  ggplot(d, aes(year_id)) +
    geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55", linewidth = .8) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = CF, alpha = .22) +
    geom_line(aes(y = cf), colour = CF, linetype = 2, linewidth = 1.4) +
    geom_line(aes(y = actual), colour = TREAT, linewidth = 1.9) +
    geom_point(aes(y = actual), colour = TREAT, size = 3.4) +
    YRS + labs(y = ylab) + th()
}

# ============================ F1  coverage ====================================
lv <- unique(p[toc == "Total", .(location_name, year_id, payer, grp, coverage, uninsured_rate)])
cv <- lv[!is.na(coverage), .(v = mean(coverage)), by = .(year_id, grp, s = payer)]
un <- unique(lv[, .(location_name, year_id, grp, uninsured_rate)])[
  , .(v = mean(uninsured_rate)), by = .(year_id, grp)][, s := "unins"]
a <- rbind(cv, un)[s %chin% c("mdcd", "priv", "unins")]
a[, sf := factor(c(mdcd = "Medicaid", priv = "Private", unins = "Uninsured")[s],
                 levels = c("Medicaid", "Private", "Uninsured"))]
sv(gline(a, "Share of population (%)") + facet_wrap(~ sf, nrow = 1, scales = "free_y"),
   "f1_coverage.pdf", 245, 165)

# ============================ F2  Medicaid ====================================
md_l <- rbind(cbind(means("mdcd", "spend_per_capita"), m = "Per resident"),
              cbind(means("mdcd", "spend_per_bene"),   m = "Per enrollee"))
md_b <- rbind(cbind(band("mdcd", "spend_per_capita"), m = "Per resident"),
              cbind(band("mdcd", "spend_per_bene"),   m = "Per enrollee"))
for (d in list(md_l, md_b)) d[, mf := factor(m, levels = c("Per resident", "Per enrollee"))]
sv(gline(md_l, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f2_medicaid_lines.pdf", 245, 165)
sv(gband(md_b, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f2_medicaid_band.pdf", 245, 165)

# ============================ F3  private =====================================
pv_l <- rbind(cbind(means("priv", "spend_per_bene"), m = "Spending per enrollee ($)"),
              cbind(means("priv", "vol_per_bene"),   m = "Encounters per enrollee"))
pv_b <- rbind(cbind(band("priv", "spend_per_bene"), m = "Spending per enrollee ($)"),
              cbind(band("priv", "vol_per_bene"),   m = "Encounters per enrollee"))
for (d in list(pv_l, pv_b)) d[, mf := factor(m, levels = c("Spending per enrollee ($)",
                                                           "Encounters per enrollee"))]
sv(gline(pv_l, NULL) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_lines.pdf", 245, 165)
sv(gband(pv_b, NULL) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_band.pdf", 245, 165)

# ============================ F4  three payers ================================
al_l <- rbindlist(lapply(names(PAY3), function(x)
  cbind(means(x, "spend_per_capita"), m = PAY3[[x]])))
al_b <- rbindlist(lapply(names(PAY3), function(x)
  cbind(band(x, "spend_per_capita"), m = PAY3[[x]])))
for (d in list(al_l, al_b)) d[, mf := factor(m, levels = PAY3)]
sv(gline(al_l, "Dollars per resident") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f4_payers_lines.pdf", 245, 165)
sv(gband(al_b, "Dollars per resident") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f4_payers_band.pdf", 245, 165)

# ============================ TABLES ==========================================
# Written as markdown so the numbers can be pasted into poster.qmd, which is
# the editable source. Regenerate after any change to the estimates.
ov <- fread("notes/evidence/overall_att.csv")
md <- function(x, f) writeLines(x, file.path(TAB, f))

cvt <- rbind(ov[outcome == "coverage" & payer != "mdcr", .(m = PAYERS[payer], att, se, pre_p)],
             ov[outcome == "uninsured", .(m = "Uninsured", att, se, pre_p)],
             ov[outcome == "coverage" & payer == "mdcr", .(m = "Medicare", att, se, pre_p)])
md(c("| Coverage | Effect | 95% CI | Pre-test |",
     "|:---------|-------:|:-------|---------:|",
     cvt[order(-att), sprintf("| %s | %+.2f | [%+.2f, %+.2f] | %.2f |",
                              m, att, att - 1.96 * se, att + 1.96 * se, pre_p)]),
   "t1_coverage.md")

# Multiple comparisons (Decision 3). The family is the 36 estimates the poster
# actually reports -- 3 payers x 6 settings x 2 spending margins -- since that
# is what a reader sees. Stars mark Benjamini-Hochberg q < 0.05, not raw p.
e2 <- eff[payer %chin% names(PAY3) & outcome %chin% c("spend_per_capita", "spend_per_bene")]
e2[, q := p.adjust(p, "BH")]
e2[, cell := sprintf("%+.1f (%.1f)%s", pct, pct_se, fifelse(q < .05, " *", ""))]
fwrite(e2[, .(payer, toc, outcome, pct, pct_se, p, q)], "results/poster_family_bh.csv")
for (out in c("spend_per_capita", "spend_per_bene")) {
  w <- dcast(e2[outcome == out], toc ~ payer, value.var = "cell")
  w[, ord := match(toc, names(SETTINGS))]; setorder(w, ord)
  md(c(sprintf("**Spending per %s**", fifelse(out == "spend_per_capita", "resident", "enrollee")),
       "", "| Setting | Medicaid | Medicare | Private |",
       "|:--------|---------:|---------:|--------:|",
       w[, sprintf("| %s | %s | %s | %s |", SETTINGS[toc], mdcd, mdcr, priv)]),
     sprintf("t2_%s.md", out))
}

cat("assets written\n")
