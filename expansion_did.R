library(data.table)
library(tidyverse)
library(arrow)
library(fixest)

dt <- fread("~/Downloads/United States Health Care Spending by Health Condition and County 2010-2019 (DEX)/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV")
medicaid_expansion <- fread("~/Downloads/medicaid_expansion_raw_data.csv")
colnames(medicaid_expansion) <- c("location_name","expansion","expansion_year")

dt <- dt[age_name == "Age/sex-standardized" & toc %in% c("AM","ED","IP","NF","RX")]

 # Identify 2014 expanders and never-expanders
medicaid_expansion[, group := fifelse(is.na(expansion_year), "Never Expanded",
                               fifelse(expansion_year == 2014, "Expanded 2014", "Later Expansion"))]

# Merge updated expansion info into main data
dt <- merge(dt, medicaid_expansion[, .(location_name, expansion_year, group)], by = "location_name", all.x = TRUE)

# Keep all state-years for 2014 expanders and never-expanders
# For later expanders, keep only pre-expansion years
dt <- dt[group %in% c("Expanded 2014", "Never Expanded") | (group == "Later Expansion" & year_id < expansion_year)]

trend_data <- dt[(group == "Never Expanded" | group == "Expanded 2014"), 
                 .(mean_spend = mean(spend_per_bene_mean, na.rm = TRUE)), 
                 by = .(year_id, group, payer, toc)]

ggplot(trend_data, aes(x = year_id, y = mean_spend, color = group)) +
  geom_vline(aes(xintercept = 2014)) +
  geom_line() +
  facet_wrap(toc ~ payer, scales = "free_y", nrow = 5) +
  labs(color = "Group", y = "Mean Spend", x = "Year") +
  theme_bw()

# Parallel trends check: fit linear model for pre-2014 only
library(broom)
pre_2014 <- dt[year_id < 2014]
pre_2014[, group := factor(group, levels = c("Expanded 2014", "Never Expanded", "Later Expansion"))]

trend_tests <- pre_2014[, {
  model <- lm(spend_per_capita_mean ~ year_id * group, data = .SD)
  tidy(model)
}, by = .(payer, toc)]


print(trend_tests[grepl("year_id:groupNever Expanded", term)])

# Placebo test: pretend expansion happened in 2012 and test for effects
placebo_year <- 2012
dt[, rel_placebo := year_id - placebo_year]
placebo_pre <- dt[year_id < placebo_year & group %in% c("Expanded 2014", "Never Expanded")]
placebo_pre[, group := factor(group, levels = c("Expanded 2014", "Never Expanded"))]

placebo_results <- placebo_pre[, {
  model <- lm(spend_per_capita_mean ~ rel_placebo * group, data = .SD)
  tidy(model)
}, by = .(payer, toc)]

print(placebo_results[grepl("rel_placebo:groupNever Expanded", term)])

# Difference-in-Differences analysis: 2014 expansion vs never-expanded
dt[, post := year_id >= 2014]
dt[, treat := as.integer(group == "Expanded 2014")]
dt[, post_treat := post * treat]

did_results <- dt[group %in% c("Expanded 2014", "Never Expanded")][, {
  model <- feols(spend_per_capita_mean ~ post_treat | location_name + year_id, 
                 cluster = ~location_name, data = .SD)
  list(model = list(model))
}, by = .(payer, toc)]

# Extract the list of models for modelsummary
models <- did_results[, model]
names(models) <- paste0(did_results$payer, " - ", did_results$toc)

library(modelsummary)

# Summary table: average spending by payer and type of care
avg_spending <- dt[, .(
  avg_spend_per_capita = mean(spend_per_capita_mean, na.rm = TRUE),
  avg_spend_per_bene = mean(spend_per_bene_mean, na.rm = TRUE)
), by = .(payer, toc)]

print(avg_spending)

modelsummary(models, statistic = "({std.error})", stars = TRUE, output = "spending_did_results.html")

# communications - 1-2 figures with specification
# cool use case of modeled data from dex
# benchmark against amy finkelstein, oregon experiment
# mostly focus on medicaid spillover - allows for insight into the quesion about how programs impact each other
# private - do marketplaces count? captures

# would want to see an event study to confirm statistical validity
# write as a policy brief - cannot see spillovers in system due to fragmentation
# not a perfect substitution but kind of
# write brief communication now and let review add complexity

# event study can tell if it takes time for spillovers to occur


