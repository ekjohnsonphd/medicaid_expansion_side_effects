# Figures for slides/eda_deck.tex
# Exploratory description of DEX 2.0 before any model is fit.

library(data.table)
library(ggplot2)

NAVY <- "#2E4057"; TEAL <- "#048A81"; ORANGE <- "#E85D04"; PURPLE <- "#9D4EDD"
WGRAY <- "#6C757D"; LGRAY <- "#E9ECEF"; RED <- "#D62828"; GOLD <- "#D4A03A"
BG <- "#FAFAFA"
OUT <- "slides/figures_eda"

base <- function(sz = 10) {
  theme_minimal(base_size = sz) +
    theme(plot.background = element_rect(fill = BG, colour = NA),
          panel.background = element_rect(fill = BG, colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = LGRAY, linewidth = 0.35),
          axis.title = element_text(colour = WGRAY, size = rel(0.85)),
          axis.text = element_text(colour = NAVY),
          strip.text = element_text(colour = NAVY, face = "bold", size = rel(0.95)),
          legend.position = "none", text = element_text(colour = NAVY))
}
sv <- function(p, f, w, h) ggsave(file.path(OUT, f), p, width = w, height = h, device = "pdf")

DEX <- "data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV"
d   <- fread(DEX)
coh <- fread("data/medicaid_expansion_cohorts.csv")

# Recover the denominators. In the All-ages data these are exact.
mk <- function(age) {
  x <- d[age_name == age & location_name != "United States"]
  x[, `:=`(bene = spend_mean / spend_per_bene_mean,
           pop  = spend_mean / spend_per_capita_mean)]
  x[, vol := vol_per_bene_mean / 1000 * bene]
  merge(x, coh[, .(location_name, expansion_year)], by = "location_name")
}
a  <- mk("All ages")
st <- mk("Age/sex-standardized")

a[, grp := fifelse(expansion_year == 2014, "2014 expanders",
            fifelse(expansion_year == 0, "Never expanded", "Later cohorts"))]
GRP <- c("2014 expanders", "Never expanded")
gcol <- c("2014 expanders" = TEAL, "Never expanded" = ORANGE)

# --- 1. Why the age basis matters: implied population by TOC ---------------
p1d <- rbind(
  a [payer=="mdcd" & location_name=="California" & year_id==2015, .(toc, pop, basis="All ages")],
  st[payer=="mdcd" & location_name=="California" & year_id==2015, .(toc, pop, basis="Age/sex-standardized")])
p1 <- ggplot(p1d, aes(pop/1e6, toc, colour = basis)) +
  geom_point(size = 2.6) +
  scale_colour_manual(values = c("All ages" = TEAL, "Age/sex-standardized" = RED)) +
  facet_wrap(~basis, nrow = 1) +
  labs(x = "Implied population (millions)", y = NULL) + base()
sv(p1, "age_basis.pdf", 6.4, 2.2)

# --- population-weighted components, Medicaid, all TOC ---------------------
comp <- function(dt, pay = "mdcd") {
  s <- dt[payer == pay & grp %in% GRP,
          .(spend = sum(spend_mean), bene = sum(bene[toc == "IP"]),
            pop = sum(pop[toc == "IP"]), vol = sum(vol)), by = .(grp, year_id)]
  s[, `:=`(Coverage = 100 * bene / pop,
           `Spend per enrollee` = spend / bene,
           `Volume per enrollee` = vol / bene * 1000,
           `Price per unit` = spend / vol,
           `Spend per capita` = spend / pop)]
  s[]
}
s <- comp(a)

# Lines are labelled directly at their right-hand end, so the reader never has
# to consult a legend.
lineplot <- function(dt, yvar, ylab) {
  lab <- dt[year_id == max(year_id), .(year_id, y = get(yvar), grp)]
  ggplot(dt, aes(year_id, get(yvar), colour = grp)) +
    geom_vline(xintercept = 2013.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
    geom_line(linewidth = 0.8) + geom_point(size = 1.3) +
    geom_text(data = lab, aes(year_id + 0.15, y, label = grp),
              hjust = 0, size = 2.9, fontface = "bold", show.legend = FALSE) +
    scale_colour_manual(values = gcol) +
    scale_x_continuous(breaks = seq(2010, 2018, 2), limits = c(2010, 2022.6)) +
    labs(x = NULL, y = ylab) + base()
}
sv(lineplot(s, "Coverage", "Enrollees as % of population"), "coverage.pdf", 6.4, 2.5)
sv(lineplot(s, "Spend per enrollee", "$ per enrollee"),      "spb.pdf",      6.4, 2.5)
sv(lineplot(s, "Volume per enrollee", "Units per 1,000 enrollees"), "vpb.pdf", 6.4, 2.5)
sv(lineplot(s, "Price per unit", "$ per unit of volume"),    "price.pdf",    6.4, 2.5)
sv(lineplot(s, "Spend per capita", "$ per resident"),        "spc.pdf",      6.4, 2.5)

# --- 2. All five components, indexed to 2013 = 100 -------------------------
long <- melt(s, id.vars = c("grp", "year_id"),
             measure.vars = c("Coverage", "Price per unit", "Volume per enrollee",
                              "Spend per enrollee", "Spend per capita"),
             variable.name = "component")
long[, idx := 100 * value / value[year_id == 2013], by = .(grp, component)]
long[, component := factor(component, levels = c("Coverage", "Price per unit",
     "Volume per enrollee", "Spend per enrollee", "Spend per capita"))]
p2 <- ggplot(long, aes(year_id, idx, colour = grp)) +
  geom_hline(yintercept = 100, colour = WGRAY, linewidth = 0.3) +
  geom_vline(xintercept = 2013.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.1) +
  facet_wrap(~component, nrow = 1) +
  scale_colour_manual(values = gcol) +
  scale_x_continuous(breaks = c(2010, 2014, 2018)) +
  labs(x = NULL, y = "Index, 2013 = 100") + base(9)
sv(p2, "components.pdf", 6.6, 2.3)

# --- 3. State-level dose-response ------------------------------------------
sw <- a[payer == "mdcd" & grp %in% GRP & year_id %in% c(2013, 2016),
        .(spend = sum(spend_mean), bene = sum(bene[toc == "IP"]), pop = sum(pop[toc == "IP"])),
        by = .(location_name, grp, year_id)]
sw[, `:=`(cov = 100 * bene / pop, spc = spend / pop)]
wide <- dcast(sw, location_name + grp ~ year_id, value.var = c("cov", "spc"))
wide[, `:=`(dcov = cov_2016 - cov_2013, dspc = spc_2016 - spc_2013)]
p3 <- ggplot(wide, aes(dcov, dspc, colour = grp)) +
  geom_hline(yintercept = 0, colour = WGRAY, linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = WGRAY, linewidth = 0.3) +
  geom_smooth(method = "lm", se = FALSE, colour = NAVY, linewidth = 0.6, linetype = "dashed") +
  geom_point(size = 2.1, alpha = 0.85) +
  scale_colour_manual(values = gcol) +
  labs(x = "Change in Medicaid coverage, 2013-2016 (pp)",
       y = "Change in Medicaid\nspend per capita ($)") + base()
sv(p3, "dose_response.pdf", 6.4, 2.6)

# --- 4. Coverage by payer ---------------------------------------------------
pay <- rbindlist(lapply(c("mdcd", "mdcr", "priv"), function(p) {
  z <- comp(a, p); z[, payer := c(mdcd = "Medicaid", mdcr = "Medicare", priv = "Private")[p]]; z }))
pay[, payer := factor(payer, levels = c("Medicaid", "Medicare", "Private"))]
plab <- pay[year_id == max(year_id)]
plab[, short := fifelse(grp == "2014 expanders", "expanders", "never")]
p4 <- ggplot(pay, aes(year_id, Coverage, colour = grp)) +
  geom_vline(xintercept = 2013.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.2) +
  geom_text(data = plab, aes(year_id + 0.2, Coverage, label = short),
            hjust = 0, size = 2.5, fontface = "bold", show.legend = FALSE) +
  facet_wrap(~payer, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = gcol) +
  scale_x_continuous(breaks = c(2010, 2014, 2018), limits = c(2010, 2023.5)) +
  labs(x = NULL, y = "Enrollees as % of population") + base()
sv(p4, "coverage_payers.pdf", 6.4, 2.3)

# --- 5. Spaghetti: every state's Medicaid coverage --------------------------
sp <- a[payer == "mdcd" & toc == "IP" & grp %in% GRP,
        .(cov = 100 * bene / pop), by = .(location_name, grp, year_id)]
p5 <- ggplot(sp, aes(year_id, cov, group = location_name, colour = grp)) +
  geom_vline(xintercept = 2013.5, colour = WGRAY, linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.45, alpha = 0.55) +
  facet_wrap(~grp, nrow = 1) +
  scale_colour_manual(values = gcol) +
  scale_x_continuous(breaks = c(2010, 2014, 2018)) +
  labs(x = NULL, y = "Medicaid enrollees as % of population") + base()
sv(p5, "coverage_states.pdf", 6.4, 2.4)

# --- 6. Decomposition by type of care ---------------------------------------
tc <- a[payer == "mdcd" & grp %in% GRP & toc %chin% c("AM","ED","IP","NF","RX") &
        year_id %in% c(2013, 2016),
        .(spend = sum(spend_mean), vol = sum(vol), bene = sum(bene), pop = sum(pop)),
        by = .(toc, grp, year_id)]
tc[, `:=`(spb = spend/bene, spc = spend/pop, vpb = vol/bene*1000)]
tl <- melt(tc, id.vars = c("toc","grp","year_id"),
           measure.vars = c("spb","vpb","spc"), variable.name = "metric")
tl <- dcast(tl, toc + grp + metric ~ year_id, value.var = "value")
tl[, pct := 100 * (`2016`/`2013` - 1)]
tl[, metric := factor(metric, levels = c("spb","vpb","spc"),
      labels = c("Spend per enrollee", "Volume per enrollee", "Spend per capita"))]
tl[, toc_f := factor(c(AM="Ambulatory",ED="Emergency",IP="Inpatient",
                       NF="Nursing fac.",RX="Pharmacy")[toc],
                     levels = rev(c("Ambulatory","Emergency","Inpatient","Nursing fac.","Pharmacy")))]
p6 <- ggplot(tl, aes(pct, toc_f, fill = grp)) +
  geom_vline(xintercept = 0, colour = WGRAY, linewidth = 0.3) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  facet_wrap(~metric, nrow = 1) +
  scale_fill_manual(values = gcol) +
  labs(x = "% change, 2013 to 2016", y = NULL) + base()
sv(p6, "by_toc.pdf", 6.6, 2.4)

message("EDA figures written to ", OUT)
