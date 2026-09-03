# ==============================================================================
# Poster assets, in two styles.
#
#   lines  : treated and control group means -- the plot a health economist
#            expects to see
#   banded : treated actual vs event-study counterfactual with a 95% band
#   event  : the event study itself -- ATT by year relative to 2014, with the
#            pre-period coefficients visible as the parallel-trends test
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
use_style <- function(style = c("lines", "band", "event")) {
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
# One fit per (payer, outcome, setting); band() and esd() both draw on it.
FITS <- new.env(parent = emptyenv())
fit1 <- function(py, out, tc = "Total") {
  k <- paste(py, out, tc)
  if (is.null(FITS[[k]])) assign(k, cs_fit(p[payer == py & toc == tc], out), FITS)
  get(k, FITS)
}
band <- function(py, out, tc = "Total") {
  d <- p[payer == py & toc == tc]
  f <- fit1(py, out, tc)
  act <- d[expansion_year == 2014, .(actual = mean(get(out))), by = year_id]
  es <- copy(f$es)[, year_id := event_time + 2014]
  m <- merge(act, es, by = "year_id", all.x = TRUE)
  m[is.na(att), `:=`(att = 0, se = 0)]
  m[, `:=`(cf = actual - att, lo = actual - att - 1.96 * se,
           hi = actual - att + 1.96 * se)][]
}

# Event study on the poster's own scale: the ATT at each event time divided by
# the pre-2014 mean in the treated states, so panels with different units are
# readable side by side.
esd <- function(py, out, tc = "Total") {
  f <- fit1(py, out, tc); b <- f$overall$base
  f$es[, .(t = event_time, pct = 100 * att / b,
           lo = 100 * (att - 1.96 * se) / b, hi = 100 * (att + 1.96 * se) / b)]
}

# ---------- the three idioms --------------------------------------------------
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

gevent <- function(d, ylab = "Effect, % of pre-2014 level") {
  ggplot(d, aes(t)) +
    geom_hline(yintercept = 0, colour = "grey45", linewidth = .8) +
    geom_vline(xintercept = -0.5, linetype = 2, colour = "grey55", linewidth = .8) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = TREAT, alpha = .18) +
    geom_line(aes(y = pct), colour = TREAT, linewidth = 1.8) +
    geom_point(aes(y = pct), colour = TREAT, size = 3.4) +
    scale_x_continuous("Years since expansion", breaks = c(-2, 0, 2, 4)) +
    labs(y = ylab) + th() + theme(legend.position = "none")
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
md_e <- rbind(cbind(esd("mdcd", "spend_per_capita"), m = "Per resident"),
              cbind(esd("mdcd", "spend_per_bene"),   m = "Per enrollee"))
for (d in list(md_l, md_b, md_e)) d[, mf := factor(m, levels = c("Per resident", "Per enrollee"))]
sv(gline(md_l, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f2_medicaid_lines.pdf", 245, 165)
sv(gband(md_b, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f2_medicaid_band.pdf", 245, 165)
sv(gevent(md_e) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f2_medicaid_event.pdf", 245, 165)

# ============================ F3  private =====================================
# NOT encounters per enrollee: at toc == "Total" that sums prescription fills
# with hospital stays, and the sum is dominated by fills. The two spending
# margins are the pair the panel actually argues about -- per enrollee for
# whether the risk pool changed, per resident for whether the sector shrank.
PVM <- c("Per enrollee", "Per resident")
pv_l <- rbind(cbind(means("priv", "spend_per_bene"),   m = PVM[1]),
              cbind(means("priv", "spend_per_capita"), m = PVM[2]))
pv_b <- rbind(cbind(band("priv", "spend_per_bene"),   m = PVM[1]),
              cbind(band("priv", "spend_per_capita"), m = PVM[2]))
pv_e <- rbind(cbind(esd("priv", "spend_per_bene"),   m = PVM[1]),
              cbind(esd("priv", "spend_per_capita"), m = PVM[2]))
for (d in list(pv_l, pv_b, pv_e)) d[, mf := factor(m, levels = PVM)]
sv(gline(pv_l, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_lines.pdf", 245, 165)
sv(gband(pv_b, "Dollars per year") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_band.pdf", 245, 165)
sv(gevent(pv_e) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_event.pdf", 245, 165)

# Alternative F3, for comparison only: spending per enrollee beside AMBULATORY
# encounters per enrollee -- a real unit, unlike the cross-setting total. Not
# used, because that model fails the parallel-trends pre-test (p = 0.010).
# To adopt it:  file.copy(file.path(FIG, "f3_private_event_vol.png"),
#                         file.path(FIG, "f3_private.png"), overwrite = TRUE)
pv_v <- rbind(cbind(esd("priv", "spend_per_bene"),          m = "Spending per enrollee"),
              cbind(esd("priv", "vol_per_bene", "AM"), m = "Ambulatory encounters"))
pv_v[, mf := factor(m, levels = c("Spending per enrollee", "Ambulatory encounters"))]
sv(gevent(pv_v) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f3_private_event_vol.pdf", 245, 165)

# ============================ F4  three payers ================================
al_l <- rbindlist(lapply(names(PAY3), function(x)
  cbind(means(x, "spend_per_capita"), m = PAY3[[x]])))
al_b <- rbindlist(lapply(names(PAY3), function(x)
  cbind(band(x, "spend_per_capita"), m = PAY3[[x]])))
al_e <- rbindlist(lapply(names(PAY3), function(x)
  cbind(esd(x, "spend_per_capita"), m = PAY3[[x]])))
for (d in list(al_l, al_b, al_e)) d[, mf := factor(m, levels = PAY3)]
sv(gline(al_l, "Dollars per resident") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f4_payers_lines.pdf", 245, 165)
sv(gband(al_b, "Dollars per resident") + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f4_payers_band.pdf", 245, 165)
sv(gevent(al_e) + facet_wrap(~ mf, nrow = 1, scales = "free_y"),
   "f4_payers_event.pdf", 245, 165)

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

# Multiple comparisons (Decision 3). The family is every estimate the poster
# reports -- 3 payers x 6 settings x 2 spending margins, plus 3 x 5 x 2
# encounter margins -- since that is what a reader sees. The All-care row is
# dropped from the encounter tables: summing across settings adds a hospital
# stay to a prescription fill, so the total has no natural unit. That leaves 66.
# Stars mark Benjamini-Hochberg q < 0.05, not raw p.
OUT4 <- c(spend_per_capita = "Spending per resident",
          spend_per_bene   = "Spending per enrollee",
          vol_per_capita   = "Encounters per resident",
          vol_per_bene     = "Encounters per enrollee")
e2 <- eff[payer %chin% names(PAY3) & outcome %chin% names(OUT4)]
e2 <- e2[!(outcome %like% "^vol" & toc == "Total")]
stopifnot(nrow(e2) == 66)
e2[, q := p.adjust(p, "BH")]
e2[, cell := sprintf("%+.1f (%.1f)%s", pct, pct_se, fifelse(q < .05, " *", ""))]
fwrite(e2[, .(payer, toc, outcome, pct, pct_se, p, q)], "results/poster_family_bh.csv")
for (out in names(OUT4)) {
  w <- dcast(e2[outcome == out], toc ~ payer, value.var = "cell")
  w[, ord := match(toc, names(SETTINGS))]; setorder(w, ord)
  md(c(sprintf("**%s**", OUT4[[out]]), "",
       "| Setting | Medicaid | Medicare | Private |",
       "|:--------|---------:|---------:|--------:|",
       w[, sprintf("| %s | %s | %s | %s |", SETTINGS[toc], mdcd, mdcr, priv)]),
     sprintf("t2_%s.md", out))
}

cat("assets written\n")
