# Event-study figure: spending per capita by payer and type of care.
# Reads results/event_study_estimates.csv produced by expansion_CSA.R.

source("~/R/utils/theme_emily.R")
library(data.table)
library(ggplot2)

est <- fread("results/event_study_estimates.csv")

payer_labels <- c(mdcd = "Medicaid", mdcr = "Medicare",
                  priv = "Private Insurance", oop = "Out-of-pocket")
toc_labels   <- c(Total = "All care", AM = "Ambulatory", ED = "Emergency Dept",
                  IP = "Inpatient", NF = "Nursing Facility", RX = "Pharmacy")

make_fig <- function(smp, outcome_var = "spend_per_capita_mean", ylab = "Estimate ($ per capita)") {
  d <- est[spec == "main" & sample == smp & outcome == outcome_var &
           event_time %between% c(-4, 4)]
  d[, payer_label := factor(payer_labels[payer], levels = payer_labels)]
  d[, toc_label   := factor(toc_labels[toc],     levels = toc_labels)]

  subtitle <- if (smp == "c2014") {
    "2014 expansion cohort vs. never-expanded states; 95% CI"
  } else {
    "All 2014-2017 expansion cohorts, not-yet-treated controls; 95% CI"
  }

  p <- ggplot(d, aes(x = event_time, y = att, colour = payer_label, fill = payer_label)) +
    geom_hline(yintercept = 0,    colour = "#999999", linewidth = 0.3) +
    geom_vline(xintercept = -0.5, colour = "#999999", linetype = "dashed", linewidth = 0.3) +
    geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, colour = NA) +
    geom_point(size = 1.0) +
    geom_line(linewidth = 0.5) +
    facet_grid(toc_label ~ payer_label, scales = "free_y") +
    scale_x_continuous(breaks = c(-4, -2, 0, 2, 4)) +
    scale_color_emily() +
    scale_fill_emily() +
    guides(colour = "none", fill = "none") +
    theme_emily_facet(base_size = 8) +
    labs(
      title    = "Medicaid expansion raised Medicaid spending per capita",
      subtitle = paste0(subtitle, "; Callaway & Sant'Anna (2021), outcome regression"),
      x        = "Years relative to expansion",
      y        = ylab
    )

  for (ext in c("pdf", "png")) {
    ggsave(sprintf("figures/fig_event_study_%s.%s", smp, ext), plot = p,
           width = 183, height = 220, units = "mm", dpi = if (ext == "pdf") 300 else 150)
  }
  message("Saved: figures/fig_event_study_", smp, ".{pdf,png}")
}

make_fig("c2014")
make_fig("all_cohorts")
