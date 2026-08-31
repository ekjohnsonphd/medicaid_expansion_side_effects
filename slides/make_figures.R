# Figures for slides/medicaid_expansion_results.tex
# Palette matches the deck's Warm Professional colours.

library(data.table)
library(ggplot2)

NAVY <- "#2E4057"; TEAL <- "#048A81"; ORANGE <- "#E85D04"; PURPLE <- "#9D4EDD"
WGRAY <- "#6C757D"; LGRAY <- "#E9ECEF"; RED <- "#D62828"; GOLD <- "#D4A03A"
BG <- "#FAFAFA"

payer_col <- c(mdcd = NAVY, mdcr = RED, priv = GOLD, oop = PURPLE)
payer_lab <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private", oop = "Out-of-pocket")
toc_lab   <- c(Total = "All care", AM = "Ambulatory", ED = "Emergency",
               IP = "Inpatient", NF = "Nursing facility", RX = "Pharmacy")

base <- function(sz = 10) {
  theme_minimal(base_size = sz) +
    theme(plot.background  = element_rect(fill = BG, colour = NA),
          panel.background = element_rect(fill = BG, colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = LGRAY, linewidth = 0.4),
          axis.title = element_text(colour = WGRAY, size = rel(0.85)),
          axis.text  = element_text(colour = NAVY),
          strip.text = element_text(colour = NAVY, face = "bold", size = rel(0.95)),
          plot.title = element_text(colour = NAVY, face = "bold", size = rel(1.05)),
          legend.position = "none",
          text = element_text(colour = NAVY))
}
sv <- function(p, f, w, h) ggsave(file.path("slides/figures", f), p, width = w, height = h, device = "pdf")

est <- fread("results/event_study_estimates.csv")
ovr <- fread("results/overall_att.csv")
pre <- fread("results/pretrend_tests.csv")

# --- 1. Medicaid event study, per capita, by type of care -----------------
d1 <- est[spec == "main" & sample == "c2014" & payer == "mdcd" &
          outcome == "spend_per_capita_mean" & event_time %between% c(-3, 4)]
d1[, toc_f := factor(toc_lab[toc], levels = toc_lab)]
p1 <- ggplot(d1, aes(event_time, att)) +
  geom_hline(yintercept = 0, colour = WGRAY, linewidth = 0.4) +
  geom_vline(xintercept = -0.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = NAVY, alpha = 0.18) +
  geom_line(colour = NAVY, linewidth = 0.6) +
  geom_point(colour = NAVY, size = 1.1) +
  facet_wrap(~toc_f, scales = "free_y", nrow = 2) +
  scale_x_continuous(breaks = c(-2, 0, 2, 4)) +
  labs(x = "Years relative to expansion", y = "ATT, $ per capita") + base()
sv(p1, "es_mdcd.pdf", 6.4, 2.75)

# --- 2. All four payers, all care ----------------------------------------
d2 <- est[spec == "main" & sample == "c2014" & toc == "Total" &
          outcome == "spend_per_capita_mean" & event_time %between% c(-3, 4)]
d2[, payer_f := factor(payer_lab[payer], levels = payer_lab)]
p2 <- ggplot(d2, aes(event_time, att, colour = payer, fill = payer)) +
  geom_hline(yintercept = 0, colour = WGRAY, linewidth = 0.4) +
  geom_vline(xintercept = -0.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.18, colour = NA) +
  geom_line(linewidth = 0.6) + geom_point(size = 1.1) +
  facet_wrap(~payer_f, nrow = 1) +
  scale_colour_manual(values = payer_col) + scale_fill_manual(values = payer_col) +
  scale_x_continuous(breaks = c(-2, 0, 2, 4)) +
  labs(x = "Years relative to expansion", y = "ATT, $ per capita") + base()
sv(p2, "es_payers.pdf", 6.4, 2.5)

# --- 3. Overall ATT, spending per capita, with pre-test flag --------------
d3 <- merge(ovr[spec == "main" & sample == "c2014" & outcome == "spend_per_capita_mean"],
            pre[outcome == "spend_per_capita_mean", .(payer, toc, outcome, p_2014)],
            by = c("payer", "toc", "outcome"))
d3[, `:=`(lo = overall_att - 1.96 * overall_se, hi = overall_att + 1.96 * overall_se,
          toc_f = factor(toc_lab[toc], levels = rev(toc_lab)),
          payer_f = factor(payer_lab[payer], levels = payer_lab),
          pt = fifelse(p_2014 >= 0.05, "passes", "fails"))]
p3 <- ggplot(d3, aes(overall_att, toc_f, colour = payer, alpha = pt)) +
  geom_vline(xintercept = 0, colour = WGRAY, linewidth = 0.4) +
  geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.9) +
  geom_point(size = 1.7) +
  facet_wrap(~payer_f, nrow = 1, scales = "free_x") +
  scale_colour_manual(values = payer_col) +
  scale_alpha_manual(values = c(passes = 1, fails = 0.28)) +
  labs(x = "Overall ATT, $ per capita (95% CI)", y = NULL) + base()
sv(p3, "att_percapita.pdf", 6.4, 2.6)

# --- 4. Pre-test p-values: staggered sample vs 2014 cohort ----------------
d4 <- melt(pre, id.vars = c("payer", "toc", "outcome"),
           measure.vars = c("p_all", "p_2014"), variable.name = "smp", value.name = "p")
d4[, smp_f := factor(smp, levels = c("p_all", "p_2014"),
                     labels = c("All cohorts (2014-2017)", "2014 cohort only"))]
p4 <- ggplot(d4, aes(p, smp_f, colour = smp)) +
  geom_vline(xintercept = 0.05, colour = RED, linetype = "dashed", linewidth = 0.5) +
  geom_jitter(width = 0, height = 0.18, size = 1.2, alpha = 0.6) +
  annotate("text", x = 0.065, y = 2.45, label = "p = 0.05", colour = RED,
           hjust = 0, size = 2.9) +
  scale_colour_manual(values = c(p_all = RED, p_2014 = TEAL)) +
  scale_x_continuous(limits = c(0, 1)) +
  labs(x = "Joint pre-trend test, p-value", y = NULL) +
  base() + theme(panel.grid.major.y = element_blank(),
                 panel.grid.major.x = element_line(colour = LGRAY, linewidth = 0.4))
sv(p4, "pretest.pdf", 6.4, 1.95)

# --- 5. Pre-test pass rate by payer, 2014 cohort -------------------------
d5 <- pre[, .(pass = mean(p_2014 >= 0.05) * 100, n = .N), by = payer]
d5[, payer_f := factor(payer_lab[payer], levels = rev(payer_lab))]
p5 <- ggplot(d5, aes(pass, payer_f, fill = payer)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = sprintf("%.0f%%", pass)), hjust = -0.25,
            colour = NAVY, fontface = "bold", size = 3.4) +
  scale_fill_manual(values = payer_col) +
  scale_x_continuous(limits = c(0, 105), expand = c(0, 0)) +
  labs(x = "Models passing pre-trend test (%)", y = NULL) +
  base() + theme(panel.grid.major.y = element_blank())
sv(p5, "pass_rate.pdf", 5.8, 2.15)

message("Figures written to slides/figures/")
