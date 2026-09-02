# ==============================================================================
# D2 revisited: what does the per-enrollee effect say about WHO moved?
#
# Let s = proportional change in enrollment, r = mean spending of the movers as
# a fraction of the incumbent mean. For an exit (private):
#     m'/m = (1 - s*r) / (1 - s)
# For an entry (Medicaid):
#     m'/m = (1 + s*r) / (1 + s)
# Solve for r given the estimated per-enrollee effect m'/m.
#
# Benchmarks worth naming:
#   r = 1  movers look like incumbents  -> per-enrollee effect is ZERO
#   r = 0  movers cost nothing          -> the largest effect selection can give
# ==============================================================================

suppressMessages(library(data.table))
ov <- fread("notes/evidence/overall_att.csv")

get <- function(py, out) ov[payer == py & toc == "Total" & outcome == out]

cat("\n================ Private: who left? ================\n")
cv <- get("priv", "coverage"); pb <- get("priv", "spend_per_bene"); pc <- get("priv", "spend_per_capita")
s  <- cv$att / cv$base                      # proportional change in enrollment
cat(sprintf("  coverage effect      : %+.2f pp on a base of %.1f%%  =  %+.2f%% of enrollment\n",
            cv$att, cv$base, 100 * s))
cat(sprintf("  spending per capita  : %+.1f%%  (SE %.1f)\n", pc$pct, pc$pct_se))
cat(sprintf("  spending per enrollee: %+.1f%%  (SE %.1f)   95%% CI [%+.1f, %+.1f]\n",
            pb$pct, pb$pct_se, pb$pct - 1.96 * pb$pct_se, pb$pct + 1.96 * pb$pct_se))

cat("\n  Benchmarks for the per-enrollee effect:\n")
cat(sprintf("    leavers were average cost (r = 1) : %+.2f%%\n", 0))
maxsel <- 100 * (1 / (1 + s) - 1)   # s is negative for an exit
cat(sprintf("    leavers cost NOTHING     (r = 0) : %+.2f%%   <- most selection can give\n", maxsel))

r_of <- function(pct, s, sign = -1) {
  m <- 1 + pct / 100
  # m = (1 + s*r)/(1 + s)  ->  r = (m*(1+s) - 1)/s
  (m * (1 + s) - 1) / s
}
cat(sprintf("\n  Implied r (leaver cost as a fraction of the incumbent mean): %.2f\n",
            r_of(pb$pct, s)))
cat(sprintf("  95%% CI on r: [%.2f, %.2f]\n",
            r_of(pb$pct + 1.96 * pb$pct_se, s), r_of(pb$pct - 1.96 * pb$pct_se, s)))
cat(sprintf("\n  Test of 'leavers were average cost' (per-enrollee = 0): t = %.2f, p = %.3f\n",
            pb$att / pb$se, 2 * pnorm(-abs(pb$att / pb$se))))
cat(sprintf("  Test of 'total private spending fell proportionally' (per-capita = %.2f%%):\n", 100*s))
cat(sprintf("    t = %.2f, p = %.3f\n", (pc$pct - 100*s) / pc$pct_se,
            2 * pnorm(-abs((pc$pct - 100*s) / pc$pct_se))))

cat("\n================ Medicaid: who joined? ================\n")
cv <- get("mdcd", "coverage"); pb <- get("mdcd", "spend_per_bene"); pc <- get("mdcd", "spend_per_capita")
s <- cv$att / cv$base
cat(sprintf("  coverage effect      : %+.2f pp on a base of %.1f%%  =  %+.2f%% of enrollment\n",
            cv$att, cv$base, 100 * s))
cat(sprintf("  spending per capita  : %+.1f%%  (SE %.1f)\n", pc$pct, pc$pct_se))
cat(sprintf("  spending per enrollee: %+.1f%%  (SE %.1f)   95%% CI [%+.1f, %+.1f]\n",
            pb$pct, pb$pct_se, pb$pct - 1.96 * pb$pct_se, pb$pct + 1.96 * pb$pct_se))
cat("\n  Benchmarks:\n")
cat(sprintf("    entrants were average cost (r = 1) : %+.2f%%\n", 0))
cat(sprintf("    entrants cost NOTHING      (r = 0) : %+.2f%%\n", 100 * (1 / (1 + s) - 1)))
cat(sprintf("\n  Implied r (new enrollee cost as a fraction of an incumbent): %.2f\n",
            r_of(pb$pct, s)))
cat(sprintf("  95%% CI on r: [%.2f, %.2f]\n",
            r_of(pb$pct - 1.96 * pb$pct_se, s), r_of(pb$pct + 1.96 * pb$pct_se, s)))

# --- figure -------------------------------------------------------------------
suppressMessages({library(ggplot2); library(data.table)}); source("~/R/utils/theme_emily.R")
mk <- function(py, lab) {
  cv <- get(py, "coverage"); pb <- get(py, "spend_per_bene")
  s  <- cv$att / cv$base
  data.table(who = lab, est = pb$pct, lo = pb$pct - 1.96 * pb$pct_se,
             hi = pb$pct + 1.96 * pb$pct_se,
             avg = 0, zero = 100 * (1 / (1 + s) - 1))
}
b <- rbind(mk("priv", "Private\n(who left)"), mk("mdcd", "Medicaid\n(who joined)"))
bl <- melt(b, id.vars = "who", measure.vars = c("avg", "zero"),
           variable.name = "bm", value.name = "y")
bl[, bml := c(avg = "Movers cost the same as incumbents",
              zero = "Movers cost nothing (selection's limit)")[as.character(bm)]]

p <- ggplot(b, aes(who, est)) +
  geom_hline(yintercept = 0, colour = "grey85") +
  geom_linerange(data = bl, aes(x = who, ymin = pmin(y, 0), ymax = pmax(y, 0),
                                colour = bml), inherit.aes = FALSE,
                 linewidth = 8, alpha = .22,
                 position = position_nudge(x = .28)) +
  geom_point(data = bl, aes(who, y, colour = bml), inherit.aes = FALSE,
             size = 3.4, shape = 18, position = position_nudge(x = .28)) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = .06, linewidth = .7) +
  geom_point(size = 3.2) +
  scale_colour_manual(values = c("Movers cost the same as incumbents" = "#6C757D",
                                 "Movers cost nothing (selection's limit)" = "#B2182B"),
                      name = NULL) +
  scale_y_continuous("Effect on spending per enrollee (% of pre-level)") +
  labs(x = NULL,
       title = "What the per-enrollee margin says about who moved",
       subtitle = "Black: estimate with 95% CI. Diamonds: what composition alone would produce if the\nmovers looked like incumbents, or cost nothing at all.") +
  theme_emily(base_size = 11) + theme(legend.position = "bottom") +
  guides(colour = guide_legend(nrow = 2))
save_fig(p, "notes/evidence/E2-3_who_moved.pdf", size = "double")
