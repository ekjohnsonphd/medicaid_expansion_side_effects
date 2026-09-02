# ==============================================================================
# Effects by type of care, on four margins.
#
#   spend_per_capita  did the payer's total burden move?
#   spend_per_bene    did spending per enrollee move?  (composition + intensity)
#   vol_per_capita    did encounters per resident move?
#   vol_per_bene      did encounters per ENROLLEE move? <- the utilisation test
#
# vol_per_bene is the direct test of "the marginal enrollee uses fewer
# services": if control states added low-utilising marketplace enrollees, their
# encounters per enrollee fall, and the DiD is positive for expanders.
# ==============================================================================
source("R/prep_panel.R")
suppressMessages(library(did))
p <- prep_panel(verbose = FALSE)

grid <- rbind(
  CJ(outcome = c("spend_per_capita", "vol_per_capita"),
     payer = names(PAYERS), toc = names(SETTINGS)),
  CJ(outcome = c("spend_per_bene", "vol_per_bene"),
     payer = c("mdcd", "mdcr", "priv"), toc = names(SETTINGS)))

message("fitting ", nrow(grid), " models ...")
res <- rbindlist(lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i]
  f <- cs_fit(p[payer == g$payer & toc == g$toc], g$outcome)
  if (is.null(f)) NULL else cbind(g, f$overall)
}))
res[, `:=`(pct = 100 * att / base, pct_se = 100 * se / base)]
res[, `:=`(t = att / se)][, p := 2 * pnorm(-abs(t))]
fwrite(res, "results/toc_effects.csv")

fmt <- function(d) d[, sprintf("%6.1f (%4.1f)%s", pct, pct_se,
                               fifelse(p < .05, "*", " "))]
show <- function(py) {
  cat(sprintf("\n=== %s — effect by setting, %% of pre-2014 level (SE). * = p<0.05 ===\n",
              PAYERS[py]))
  w <- dcast(res[payer == py], toc ~ outcome, value.var = c("pct", "pct_se", "p"))
  o <- res[payer == py]
  tab <- dcast(o, toc ~ outcome, value.var = "pct")
  se  <- dcast(o, toc ~ outcome, value.var = "pct_se")
  pv  <- dcast(o, toc ~ outcome, value.var = "p")
  out <- data.table(setting = SETTINGS[tab$toc])
  for (v in c("spend_per_capita", "spend_per_bene", "vol_per_capita", "vol_per_bene")) {
    if (!v %in% names(tab)) next
    out[[v]] <- sprintf("%6.1f (%4.1f)%s", tab[[v]], se[[v]],
                        fifelse(!is.na(pv[[v]]) & pv[[v]] < .05, "*", " "))
  }
  setnames(out, c("spend_per_capita", "spend_per_bene", "vol_per_capita", "vol_per_bene"),
           c("$/capita", "$/enrollee", "vol/capita", "vol/enrollee"), skip_absent = TRUE)
  print(out, row.names = FALSE)
  cat("  pre-trend p: ",
      paste(sprintf("%s %.2f", SETTINGS[o[outcome=="spend_per_capita", toc]],
                    o[outcome=="spend_per_capita", pre_p]), collapse = " | "), "\n")
}
for (py in c("priv", "mdcd", "mdcr")) show(py)

cat("\n=== Pre-trend pass rate across all", nrow(res), "models ===\n")
print(res[, .(models = .N, pass = sum(pre_p >= .05, na.rm = TRUE),
              `pass %` = round(100 * mean(pre_p >= .05, na.rm = TRUE))), by = payer])

# --- figure: is the private effect concentrated in any setting? ---------------
suppressMessages(library(ggplot2)); source("~/R/utils/theme_emily.R")
MARG <- c(spend_per_capita = "Spending\nper resident", spend_per_bene = "Spending\nper enrollee",
          vol_per_capita = "Encounters\nper resident", vol_per_bene = "Encounters\nper enrollee")
d <- res[payer == "priv" & outcome %chin% names(MARG)]
d[, `:=`(mf = factor(MARG[outcome], levels = MARG),
         sf = factor(SETTINGS[toc], levels = rev(SETTINGS)))]
p1 <- ggplot(d, aes(pct, sf)) +
  geom_vline(xintercept = 0, colour = "grey50") +
  geom_errorbarh(aes(xmin = pct - 1.96 * pct_se, xmax = pct + 1.96 * pct_se),
                 height = 0, linewidth = .7, colour = "#2166AC", alpha = .7) +
  geom_point(size = 2.4, colour = "#2166AC") +
  facet_wrap(~ mf, nrow = 1) +
  scale_x_continuous("Effect, % of pre-expansion level") +
  labs(y = NULL, title = "Private insurance: the same small positive everywhere",
       subtitle = "No setting stands out. A uniform shift on the per-enrollee margins, and nothing per\nresident, is what dilution of the control group's risk pool looks like. 95% intervals.") +
  theme_emily(base_size = 10)
save_fig(p1, "notes/evidence/E7-1_private_by_setting.pdf", size = "double")

# Medicaid: the same panel, for contrast.
d2 <- res[payer == "mdcd" & outcome %chin% names(MARG)]
d2[, `:=`(mf = factor(MARG[outcome], levels = MARG),
          sf = factor(SETTINGS[toc], levels = rev(SETTINGS)))]
p2 <- p1 %+% d2 + labs(title = "Medicaid: everything is on the per-resident margin",
  subtitle = "Spending per resident rises across settings; per enrollee it does not move. The\nexception in total encounters is an aggregation artefact (see notes). 95% intervals.")
save_fig(p2, "notes/evidence/E7-2_medicaid_by_setting.pdf", size = "double")
