# Is the private coverage effect states LOSING private coverage, or control
# states GAINING it? The DiD coefficient cannot tell them apart; the levels can.
source("R/prep_panel.R")
suppressMessages(library(ggplot2)); source("~/R/utils/theme_emily.R")

p <- prep_panel(verbose = FALSE)
lv <- unique(p[toc == "Total", .(location_name, year_id, payer, grp, coverage,
                                 uninsured_rate)])

cov <- lv[!is.na(coverage), .(v = mean(coverage)), by = .(year_id, grp, series = payer)]
uni <- unique(lv[, .(location_name, year_id, grp, uninsured_rate)])[
  , .(v = mean(uninsured_rate)), by = .(year_id, grp)][, series := "unins"]
a <- rbind(cov, uni)
LAB <- c(mdcd = "Medicaid", priv = "Private", unins = "Uninsured", mdcr = "Medicare")
a <- a[series %chin% names(LAB)]
a[, sf := factor(LAB[series], levels = LAB)]

cat("\n=== Coverage LEVELS by group (%), and the change over expansion ===\n")
w <- dcast(a[year_id %in% c(2013, 2018)], sf + grp ~ year_id, value.var = "v")
setnames(w, c("2013", "2018"), c("y2013", "y2018"))
w[, change := y2018 - y2013]
print(w[order(sf, grp), .(series = sf, grp,
                          `2013` = round(y2013, 1), `2018` = round(y2018, 1),
                          `change (pp)` = round(change, 2))])

cat("\n=== The DiD, read off the levels ===\n")
d <- dcast(w, sf ~ grp, value.var = "change")
setnames(d, c("2014 expanders (25)", "Never expanded (19)"), c("exp", "nev"))
print(d[, .(series = sf, `expanders` = round(exp, 2), `never` = round(nev, 2),
            `difference` = round(exp - nev, 2))])

cat("\n  Read the private row carefully: a negative DiD can come from expanders\n")
cat("  falling, from never-expanders rising, or from both.\n")

# --- the ratio Emily asked about ---------------------------------------------
ov <- fread("notes/evidence/overall_att.csv")
md <- ov[outcome == "coverage" & payer == "mdcd"]; pv <- ov[outcome == "coverage" & payer == "priv"]
R  <- abs(pv$att) / md$att
se <- R * sqrt((pv$se / pv$att)^2 + (md$se / md$att)^2)   # delta method, independence assumed
cat(sprintf("\n=== The '58%%' figure ===\n"))
cat(sprintf("  |private ATT| / Medicaid ATT = %.2f / %.2f = %.3f\n", abs(pv$att), md$att, R))
cat(sprintf("  delta-method SE %.3f, approximate 95%% CI [%.0f%%, %.0f%%]\n",
            se, 100 * (R - 1.96 * se), 100 * (R + 1.96 * se)))

p1 <- ggplot(a, aes(year_id, v, colour = grp)) +
  geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey55") +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  facet_wrap(~ sf, scales = "free_y", nrow = 1) +
  scale_x_continuous("", breaks = seq(2010, 2018, 4)) +
  scale_y_continuous("Share of population (%)") +
  scale_color_emily("primary", name = NULL) +
  labs(title = "Coverage levels, not differences",
       subtitle = "A negative difference-in-differences on private coverage can mean expanders lost it,\nor that never-expanders gained it. These are the levels.") +
  theme_emily(base_size = 10) + theme(legend.position = "bottom")
save_fig(p1, "notes/evidence/E6-1_coverage_levels.pdf", size = "double")

# If the private DiD is control states ADDING low-income marketplace enrollees,
# then private spending per enrollee should have grown more slowly in the
# CONTROL group -- and the positive treated-vs-control per-enrollee effect is
# a control-group composition story, not a treated-group one.
cat("\n=== Private spending per enrollee, levels by group ===\n")
pe <- p[payer == "priv" & toc == "Total",
        .(spb = mean(spend_per_bene), spc = mean(spend_per_capita),
          cov = mean(coverage)), by = .(year_id, grp)]
print(pe[year_id %in% c(2013, 2018)][order(grp, year_id)][
  , .(grp, year_id, `spend/enrollee` = round(spb), `spend/capita` = round(spc),
      `coverage %` = round(cov, 1))])
ch <- dcast(pe[year_id %in% c(2013, 2018)], grp ~ year_id, value.var = "spb")
setnames(ch, c("2013", "2018"), c("a", "b")); ch[, growth := 100 * (b / a - 1)]
cat("\n  Growth in private spending per enrollee, 2013->2018:\n")
print(ch[, .(grp, `growth %` = round(growth, 1))])
cat(sprintf("\n  Difference: %.1f pp\n", ch[grp %like% "2014", growth] - ch[grp %like% "Never", growth]))
