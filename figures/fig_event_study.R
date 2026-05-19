source("~/R/utils/theme_emily.R")
library(data.table)
library(ggplot2)

dt <- fread("event_study_coefficients.csv")

payer_labels <- c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private Insurance")
toc_labels   <- c(AM = "Ambulatory", ED = "Emergency Dept",
                  IP = "Inpatient",  NF = "Nursing Facility", RX = "Pharmacy")

dt[, payer_label := factor(payer_labels[payer], levels = payer_labels)]
dt[, toc_label   := factor(toc_labels[toc],   levels = toc_labels)]

p <- ggplot(dt, aes(x = rel_year_parsed, y = estimate,
                    colour = payer_label, fill = payer_label)) +
  geom_hline(yintercept = 0,    colour = "#999999", linewidth = 0.3) +
  geom_vline(xintercept = -0.5, colour = "#999999", linetype = "dashed", linewidth = 0.3) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, colour = NA) +
  geom_point(size = 1.0) +
  geom_line(linewidth = 0.5) +
  facet_grid(toc_label ~ payer_label, scales = "free_y") +
  scale_x_continuous(breaks = c(-4, -2, 0, 2, 4)) +
  scale_color_emily() +
  scale_fill_emily() +
  guides(colour = "none", fill = "none") +
  theme_emily_facet(base_size = 8) +
  labs(
    title    = "Medicaid expansion shifted spending across payers and care settings",
    subtitle = "Event-study estimates (Callaway & Sant'Anna 2021) with 95% CI; outcome = spending per beneficiary",
    x        = "Years relative to expansion",
    y        = "Estimate ($/beneficiary)"
  )

dir.create("figures", showWarnings = FALSE)
ggsave("figures/fig_event_study.pdf", plot = p, width = 183, height = 200,
       units = "mm", dpi = 300)
ggsave("figures/fig_event_study.png", plot = p, width = 183, height = 200,
       units = "mm", dpi = 150)

message("Saved: figures/fig_event_study.pdf and figures/fig_event_study.png")
