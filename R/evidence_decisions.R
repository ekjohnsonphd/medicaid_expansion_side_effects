# ==============================================================================
# Evidence for DECISIONS 2-5.  All-ages basis, 2014 cohort vs never-expanded.
#   D2  denominator     : per capita vs per enrollee
#   D3  multiplicity    : how much of the significant set is noise?
#   D4  out-of-pocket   : what does the pre-trend failure look like?
#   D5  inference       : multiplier bootstrap vs analytic clustered SEs
# ==============================================================================

source("R/prep_panel.R")
suppressMessages({library(ggplot2); library(did)})
source("~/R/utils/theme_emily.R")
OUT <- "notes/evidence"

p <- prep_panel()

grid <- rbind(
  CJ(outcome = c("spend_per_capita"), payer = names(PAYERS), toc = names(SETTINGS)),
  CJ(outcome = c("spend_per_bene"),   payer = c("mdcd", "mdcr", "priv"), toc = names(SETTINGS)),
  CJ(outcome = "coverage",            payer = c("mdcd", "mdcr", "priv"), toc = "Total"))

message("fitting ", nrow(grid), " models (bootstrap) ...")
run <- function(bstrap) rbindlist(lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i]
  f <- cs_fit(p[payer == g$payer & toc == g$toc], g$outcome, bstrap = bstrap)
  if (is.null(f)) return(NULL)
  list(ov = cbind(g, f$overall), es = if (is.null(f$es)) NULL else cbind(g, f$es))
}) |> (\(z) list(ov = rbindlist(lapply(z, `[[`, "ov")),
                 es = rbindlist(lapply(z, `[[`, "es"))))() |> (\(z) z)()  )

fits  <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i]; cs_fit(p[payer == g$payer & toc == g$toc], g$outcome, bstrap = TRUE) })
ov <- rbindlist(Map(function(g, f) if (is.null(f)) NULL else cbind(grid[g], f$overall),
                    seq_len(nrow(grid)), fits))
es <- rbindlist(Map(function(g, f) if (is.null(f) || is.null(f$es)) NULL else cbind(grid[g], f$es),
                    seq_len(nrow(grid)), fits))
ov[, `:=`(pct = 100 * att / base, pct_se = 100 * se / base, t = att / se)]
ov[, p := 2 * pnorm(-abs(t))]
fwrite(ov, file.path(OUT, "overall_att.csv")); fwrite(es, file.path(OUT, "event_study.csv"))

# ============================== D4: out-of-pocket =============================
cat("\n================ D4  Out-of-pocket ================\n")
cat("\nPre-trend p by payer (spending per capita), all-ages basis:\n")
print(dcast(ov[outcome == "spend_per_capita"], payer ~ toc, value.var = "pre_p"))

# The raw series: what does the failure actually look like?
raw <- p[, .(y = mean(spend_per_capita)), by = .(payer, toc, year_id, grp)]
rawT <- raw[toc == "Total"]
rawT[, pf := factor(PAYERS[payer], levels = PAYERS)]
# index to 2010 so pre-period slopes are directly comparable
rawT[, idx := 100 * y / y[year_id == 2010], by = .(payer, grp)]

p4a <- ggplot(rawT, aes(year_id, idx, colour = grp)) +
  geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
  geom_line(linewidth = .9) + geom_point(size = 1.4) +
  facet_wrap(~ pf, nrow = 1) +
  scale_x_continuous("", breaks = seq(2010, 2018, 4)) +
  scale_y_continuous("Spending per capita, 2010 = 100") +
  scale_color_emily("primary", name = NULL) +
  labs(title = "Where the parallel-trends assumption holds, and where it does not",
       subtitle = "Group means, all five settings, indexed to 2010. Read the segment left of the dashed line.") +
  theme_emily(base_size = 10) + theme(legend.position = "bottom")
save_fig(p4a, file.path(OUT, "E4-1_raw_trends_by_payer.pdf"), size = "double")

# Pre-period slope difference, the thing the Wald test is reacting to.
pre <- p[year_id <= 2013 & toc == "Total",
         .(y = mean(spend_per_capita)), by = .(payer, year_id, grp)]
sl <- pre[, .(slope = coef(lm(log(y) ~ year_id))[2] * 100), by = .(payer, grp)]
cat("\nPre-2014 annual growth in spending per capita (%/yr, log slope):\n")
print(dcast(sl, payer ~ grp, value.var = "slope")[, lapply(.SD, function(z)
  if (is.numeric(z)) round(z, 2) else z)])

esT <- es[outcome == "spend_per_capita" & toc == "Total"]
esT[, pf := factor(PAYERS[payer], levels = PAYERS)]
p4b <- ggplot(esT, aes(event_time, att / rep(ov[outcome == "spend_per_capita" & toc == "Total"][
      match(esT$payer, payer), base], 1) * 100)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = 2, colour = "grey55") +
  geom_ribbon(aes(ymin = (att - 1.96 * se) / ov[outcome == "spend_per_capita" & toc == "Total"][
      match(esT$payer, payer), base] * 100,
      ymax = (att + 1.96 * se) / ov[outcome == "spend_per_capita" & toc == "Total"][
      match(esT$payer, payer), base] * 100), alpha = .18, fill = "#2166AC", colour = NA) +
  geom_line(linewidth = .8, colour = "#2166AC") + geom_point(size = 1.5, colour = "#2166AC") +
  facet_wrap(~ pf, nrow = 1) +
  scale_x_continuous("Years since expansion", breaks = seq(-4, 4, 2)) +
  scale_y_continuous("Effect, % of pre-expansion level") +
  labs(title = "Event study, spending per capita",
       subtitle = "Points left of the dashed line are the pre-trend test made visible. 95% intervals.") +
  theme_emily(base_size = 10)
save_fig(p4b, file.path(OUT, "E4-3_event_study_per_capita.pdf"), size = "double")

# ============================== D2: denominator ===============================
cat("\n================ D2  Denominator ================\n")
cov <- ov[outcome == "coverage"]
cat("\nEffect on coverage (percentage points of the population enrolled):\n")
print(cov[, .(payer, att = round(att, 2), se = round(se, 2),
              pre_p = round(pre_p, 3), base = round(base, 1))])

cmp <- dcast(ov[outcome %chin% c("spend_per_capita", "spend_per_bene") &
                payer != "oop"], payer + toc ~ outcome, value.var = "pct")
cmpse <- dcast(ov[outcome %chin% c("spend_per_capita", "spend_per_bene") &
                  payer != "oop"], payer + toc ~ outcome, value.var = "pct_se")
setnames(cmpse, c("spend_per_capita", "spend_per_bene"), c("se_pc", "se_pb"))
cmp <- merge(cmp, cmpse, by = c("payer", "toc"))
cat("\nATT as % of pre-period level, per capita vs per enrollee:\n")
print(cmp[, .(payer, toc,
              `per capita`  = sprintf("%6.1f (%4.1f)", spend_per_capita, se_pc),
              `per enrollee`= sprintf("%6.1f (%4.1f)", spend_per_bene, se_pb))], nrows = 20)

esc <- es[outcome == "coverage"]
esc[, pf := factor(PAYERS[payer], levels = PAYERS[c("mdcd","mdcr","priv")])]
p2a <- ggplot(esc, aes(event_time, att)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_vline(xintercept = -0.5, linetype = 2, colour = "grey55") +
  geom_ribbon(aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se),
              alpha = .18, fill = "#B2182B", colour = NA) +
  geom_line(linewidth = .9, colour = "#B2182B") + geom_point(size = 1.7, colour = "#B2182B") +
  facet_wrap(~ pf, nrow = 1) +
  scale_x_continuous("Years since expansion", breaks = seq(-4, 4, 2)) +
  scale_y_continuous("Effect on share of population enrolled (pp)") +
  labs(title = "The per-enrollee denominator moves at expansion",
       subtitle = "Effect on coverage. Any per-enrollee outcome is divided by a quantity the treatment changed.") +
  theme_emily(base_size = 10)
save_fig(p2a, file.path(OUT, "E2-1_coverage_event_study.pdf"), size = "double")

cmp[, pf := factor(PAYERS[payer], levels = PAYERS)]
p2b <- ggplot(cmp, aes(spend_per_capita, spend_per_bene, colour = pf)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey55") +
  geom_hline(yintercept = 0, colour = "grey85") + geom_vline(xintercept = 0, colour = "grey85") +
  geom_point(size = 2.6) +
  scale_color_emily("primary", name = NULL) +
  labs(x = "Per capita (fixed denominator), % of pre-level",
       y = "Per enrollee (denominator moves), % of pre-level",
       title = "The two denominators tell different stories",
       subtitle = "Points off the dashed line are where the enrollee count, not spending, is doing the work.") +
  theme_emily(base_size = 11) + theme(legend.position = "bottom")
save_fig(p2b, file.path(OUT, "E2-2_per_capita_vs_per_enrollee.pdf"), size = "double")

# ============================== D3: multiplicity ==============================
cat("\n================ D3  Multiplicity ================\n")
sp <- ov[outcome == "spend_per_capita"]
cat(sprintf("\nSpending-per-capita models: %d\n", nrow(sp)))
cat(sprintf("  significant at 5%%      : %d  (expected by chance if all null: %.1f)\n",
            sum(sp$p < .05), .05 * nrow(sp)))
cat(sprintf("  significant excl. Medicaid: %d of %d  (expected %.1f)\n",
            sum(sp[payer != "mdcd", p < .05]), nrow(sp[payer != "mdcd"]),
            .05 * nrow(sp[payer != "mdcd"])))
sp[, q := p.adjust(p, "BH")]
cat("\n  Surviving Benjamini-Hochberg at q < 0.05:\n")
print(sp[q < .05, .(payer, toc, pct = round(pct, 1), p = signif(p, 2), q = signif(q, 2))])

p3 <- ggplot(sp, aes(p)) +
  geom_histogram(breaks = seq(0, 1, .1), fill = "#2166AC", alpha = .85, colour = "white") +
  geom_hline(yintercept = nrow(sp) / 10, linetype = 2, colour = "grey40") +
  scale_x_continuous("p-value", breaks = seq(0, 1, .2)) +
  scale_y_continuous("Models") +
  labs(title = "Is the significant set bigger than chance would give?",
       subtitle = sprintf("%d spending-per-capita models. Dashed line is the uniform null. A spike at zero is signal;\na flat rest of the distribution means nothing else is there.", nrow(sp))) +
  theme_emily(base_size = 11)
save_fig(p3, file.path(OUT, "E3-1_pvalue_distribution.pdf"), size = "double")

# ============================== D5: inference =================================
cat("\n================ D5  Inference ================\n")
message("refitting spending-per-capita models with analytic SEs ...")
an <- rbindlist(lapply(which(grid$outcome == "spend_per_capita"), function(i) {
  g <- grid[i]; f <- cs_fit(p[payer == g$payer & toc == g$toc], g$outcome, bstrap = FALSE)
  if (is.null(f)) NULL else cbind(g, f$overall)
}))
d5 <- merge(sp[, .(payer, toc, att, se_boot = se)],
            an[, .(payer, toc, se_an = se)], by = c("payer", "toc"))
d5[, `:=`(ratio = se_boot / se_an,
          sig_boot = abs(att / se_boot) > 1.96, sig_an = abs(att / se_an) > 1.96)]
cat(sprintf("\n  bootstrap SE / analytic SE: median %.3f, range %.3f-%.3f\n",
            median(d5$ratio), min(d5$ratio), max(d5$ratio)))
cat(sprintf("  significance verdict differs in %d of %d cells\n",
            sum(d5$sig_boot != d5$sig_an), nrow(d5)))
if (any(d5$sig_boot != d5$sig_an)) print(d5[sig_boot != sig_an])
fwrite(d5, file.path(OUT, "E5-1_bootstrap_vs_analytic.csv"))
cat("\nDone.\n")
