# Event Study Analysis of Medicaid Expansion with Staggered Treatment
# Treatment: States that expanded in 2014 (first wave)
# Controls: Not-yet-treated approach (never expanders + all later expanders before treatment)
#
# Methodological approach:
# - Uses Callaway & Sant'Anna (2021) doubly-robust DiD estimator via the `did` R package
# - Uses "not-yet-treated" states as controls (never expanders + 2015+ expanders before treatment)
# - Estimates group-time average treatment effects (ATT(g,t))
# - Aggregates to event study parameters showing dynamic treatment effects
# - This approach properly handles staggered treatment adoption and heterogeneous treatment effects
#
# ==============================================================================
# DATA REQUIREMENTS FOR STATE-LEVEL COVARIATES (for doubly-robust estimation)
# ==============================================================================
# The Callaway & Sant'Anna (2021) estimator can use covariates in a doubly-robust
# framework to improve efficiency and relax the parallel trends assumption.
#
# Create a CSV file with the following columns:
#   - location_name: State name (must match main data)
#   - year_id: Year (2010-2019)
#   - population: Annual state population
#   - gdp_per_capita: State GDP per capita (or median household income)
#   - unemployment: State unemployment rate (%)
#   - poverty_rate: State poverty rate (%) or uninsured rate (%)
#
# Data sources:
#   - Population: Census Bureau (https://www.census.gov/data/tables/time-series/demo/popest/2010s-state-total.html)
#   - GDP: BEA (https://www.bea.gov/data/gdp/gdp-state)
#   - Unemployment: BLS (https://www.bls.gov/lau/)
#   - Poverty/insurance: Census ACS or Kaiser Family Foundation
#
# Once you have the data, merge it into the main dataset and uncomment the xformla
# parameter in the att_gt() call (line 264) to include covariates in the estimation.
# ==============================================================================

library(data.table)
library(tidyverse)
library(arrow)
library(did)  # Callaway & Sant'Anna (2021) package
library(modelsummary)
library(broom)
library(kableExtra)

# ==============================================================================
# CONFIGURATION: Select outcome variable
# ==============================================================================
# Choose one: "spend_per_capita_mean" or "spend_per_bene_mean"
OUTCOME_VAR <- "spend_per_bene_mean"

# ==============================================================================
# Load and prepare data
# ==============================================================================
dt <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV")
medicaid_expansion <- fread("data/medicaid_expansion_raw_data.csv")
colnames(medicaid_expansion) <- c("location_name","expansion","expansion_year")

# Filter to age-standardized and specific types of care
dt <- dt[age_name == "Age/sex-standardized" & toc %in% c("AM","ED","IP","NF","RX")]

# ==============================================================================
# Define treatment groups: Use not-yet-treated as controls
# ==============================================================================
medicaid_expansion[, group := fcase(
  is.na(expansion_year), "Never Expanded",
  expansion_year == 2014, "Expanded 2014",
  expansion_year > 2014, "Later Expansion"
)]

# Merge expansion info
dt <- merge(dt, medicaid_expansion[, .(location_name, expansion_year, group)],
            by = "location_name", all.x = TRUE)

# Keep:
# 1. States that expanded in 2014 (treatment group) - all years
# 2. Never expanded states (pure controls) - all years
# 3. Later expanders (2015+) - ONLY pre-expansion years (serve as controls before they expand)
# This approach uses "not-yet-treated" states as controls, maximizing statistical power
# dt <- dt[group == "Expanded 2014" |
#          group == "Never Expanded" |
#          (group == "Later Expansion" & year_id < expansion_year)]

# ==============================================================================
# Prepare data for did package (Callaway & Sant'Anna 2021)
# ==============================================================================
# The did package requires:
# - G: treatment timing (year of first treatment), 0 for never-treated
# - period: time period
# - outcome: dependent variable
# - id: unit identifier

# Create treatment timing variable (G in Callaway & Sant'Anna notation)
# Set to 0 for never-treated, actual expansion year for treated
dt[, G := fcase(
  group == "Never Expanded", 0L,
  default = as.integer(expansion_year)
)]

# For the did package, we need a balanced panel structure
# Ensure we have all required variables
dt[, `:=`(
  id = as.numeric(factor(location_name)),  # Unit identifier
  period = year_id      # Time period
)]

# ==============================================================================
# Calculate baseline spending (2010-2013) for use as control variable
# ==============================================================================
baseline_spend <- dt[year_id %in% 2010:2013,
                     .(baseline_spending = mean(get(OUTCOME_VAR), na.rm = TRUE)),
                     by = .(location_name, payer, toc)]

# Merge baseline spending back into main dataset
dt <- merge(dt, baseline_spend, by = c("location_name", "payer", "toc"), all.x = TRUE)

# For not yet exposed states, set expansion_year to a reference value (0)
# This allows us to include it as a control for cohort effects
dt[is.na(expansion_year), expansion_year := 0]

# ==============================================================================
# OPTIONAL: Merge state-level time-varying controls
# ==============================================================================
# Uncomment and modify the following section once you have control data:
#
# controls <- fread("path_to_state_controls.csv")  # Should have: location_name, year_id, population, gdp_per_capita, unemployment, poverty_rate
# dt <- merge(dt, controls, by = c("location_name", "year_id"), all.x = TRUE)
#
# For now, create placeholder controls (will be excluded from model):
dt[, `:=`(
  population = NA_real_,
  gdp_per_capita = NA_real_,
  unemployment = NA_real_,
  poverty_rate = NA_real_
)]

# ==============================================================================
# Baseline characteristics table (pre-expansion: 2010-2013)
# ==============================================================================
baseline_data <- dt[year_id %in% 2010:2013]

# Calculate baseline characteristics by state
baseline_chars <- baseline_data[, .(
  `Mean Spend per Capita` = mean(spend_per_capita_mean, na.rm = TRUE),
  `Mean Spend per Beneficiary` = mean(spend_per_bene_mean, na.rm = TRUE),
  `SD Spend per Capita` = sd(spend_per_capita_mean, na.rm = TRUE),
  `SD Spend per Beneficiary` = sd(spend_per_bene_mean, na.rm = TRUE),
  `N Observations` = .N
), by = .(location_name, group, expansion_year)]

# Summary by group
baseline_summary <- baseline_chars[, .(
  `States (N)` = .N,
  `Mean Spend per Capita` = sprintf("%.2f (%.2f)",
                                    mean(`Mean Spend per Capita`, na.rm = TRUE),
                                    sd(`Mean Spend per Capita`, na.rm = TRUE)),
  `Mean Spend per Beneficiary` = sprintf("%.2f (%.2f)",
                                         mean(`Mean Spend per Beneficiary`, na.rm = TRUE),
                                         sd(`Mean Spend per Beneficiary`, na.rm = TRUE))
), by = group]

print("=== BASELINE CHARACTERISTICS (2010-2013) ===")
print(baseline_summary)

# Save detailed baseline table
baseline_table <- baseline_chars[order(group, location_name)]
fwrite(baseline_table, "baseline_characteristics.csv")

# Create formatted table for paper
baseline_summary_transposed <- dcast(baseline_summary,
                                     . ~ group,
                                     value.var = c("States (N)",
                                                   "Mean Spend per Capita",
                                                   "Mean Spend per Beneficiary"))
baseline_summary_transposed[, . := NULL]

# Determine column structure based on which groups are present
groups_present <- unique(baseline_summary$group)
n_groups <- length(groups_present)

# Create column names dynamically
col_names <- rep(c("N States", "Mean Spend per Capita", "Mean Spend per Beneficiary"), n_groups)

# Create header structure
header_vec <- setNames(rep(3, n_groups), groups_present)

kbl_baseline <- kable(baseline_summary_transposed,
                      format = "html",
                      caption = "Baseline Characteristics by Expansion Status (2010-2013)",
                      col.names = col_names) %>%
  kable_styling(bootstrap_options = c("striped", "hover")) %>%
  add_header_above(header_vec)

save_kable(kbl_baseline, "baseline_characteristics_table.html")

# ==============================================================================
# Parallel trends visualization
# ==============================================================================
trend_data <- dt[, .(mean_spend = mean(get(OUTCOME_VAR), na.rm = TRUE)),
                 by = .(year_id, group, payer, toc)]

p_trends <- ggplot(trend_data, aes(x = year_id, y = mean_spend,
                                    color = group, linetype = group)) +
  geom_vline(xintercept = 2014, linetype = "dashed", color = "gray50", alpha = 0.7) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  facet_wrap(toc ~ payer, scales = "free_y", nrow = 5) +
  labs(
    title = paste("Parallel Trends by Payer and Type of Care"),
    subtitle = paste("Outcome:", OUTCOME_VAR, "| Not-yet-treated states used as controls"),
    color = "Expansion Status",
    linetype = "Expansion Status",
    y = ifelse(OUTCOME_VAR == "spend_per_capita_mean",
               "Mean Spend per Capita ($)",
               "Mean Spend per Beneficiary ($)"),
    x = "Year"
  ) +
  scale_color_manual(values = c("Expanded 2014" = "#0072B2",
                                "Never Expanded" = "#D55E00",
                                "Later Expansion" = "#009E73")) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 9),
    plot.title = element_text(face = "bold")
  )

ggsave("parallel_trends_by_model.png", p_trends, width = 14, height = 12, dpi = 300)
print("Parallel trends plot saved to: parallel_trends_by_model.png")

# ==============================================================================
# Event Study using did package (Callaway & Sant'Anna 2021)
# ==============================================================================
# Run att_gt() for each payer-toc combination
# This estimates group-time average treatment effects using not-yet-treated controls

cat("Running Callaway & Sant'Anna (2021) event study analysis...\n")

# Store results for each payer-toc combination
cs_results_list <- list()
event_study_aggregated <- list()

for (payer_val in unique(dt$payer)) {
  for (toc_val in unique(dt$toc)) {
    cat(sprintf("\nProcessing: %s - %s\n", payer_val, toc_val))

    # Subset data
    subset_dt <- dt[payer == payer_val & toc == toc_val]

    # Ensure we have enough variation - need both treated and control units
    n_treated <- length(unique(subset_dt[G > 0, id]))
    n_control <- length(unique(subset_dt[G == 0, id]))

    if (n_treated == 0 || n_control == 0) {
      cat(sprintf("  Skipping: insufficient variation (treated=%d, control=%d)\n", n_treated, n_control))
      next
    }

    # Convert to data frame and ensure proper types
    # Only keep essential columns to reduce memory usage
    subset_df <- as.data.frame(subset_dt[, .(id, period, G,
                                             outcome = get(OUTCOME_VAR))])
    subset_df$period <- as.integer(subset_df$period)
    subset_df$G <- as.integer(subset_df$G)

    # Remove any NA values in key variables
    subset_df <- subset_df[complete.cases(subset_df$outcome), ]

    cat(sprintf("  Data size: %d observations, %d treated units, %d control units\n",
                nrow(subset_df), n_treated, n_control))

    # Estimate group-time ATTs using Callaway & Sant'Anna (2021)
    # control_group = "notyettreated" uses not-yet-treated states as controls
    # xformla can include covariates for doubly-robust estimation (add when available)
    tryCatch({
      cs_result <- att_gt(
        yname = "outcome",
        tname = "period",
        idname = "id",
        gname = "G",
        data = subset_df,
        control_group = "notyettreated",
        clustervars = "id",
        est_method = "reg",  # Changed from "dr" to "reg" - less computationally intensive
        bstrap = TRUE,
        cband = FALSE,  # Disabled to reduce computational burden
        biters = 100,  # Further reduced from 250
        allow_unbalanced_panel = TRUE  # Allow unbalanced panels
        # xformla = ~1  # Add covariates here when available: ~baseline_spending + population + gdp_per_capita
      )

      # Store the att_gt object
      cs_results_list[[paste0(payer_val, "_", toc_val)]] <- cs_result

      # Aggregate to event study parameters (dynamic effects)
      es_agg <- aggte(cs_result, type = "dynamic", min_e = -5, max_e = 5)
      event_study_aggregated[[paste0(payer_val, "_", toc_val)]] <- es_agg

      cat(sprintf("  Success!\n"))

    }, error = function(e) {
      cat(sprintf("  Error for %s - %s: %s\n", payer_val, toc_val, e$message))
    })

    # Force garbage collection between iterations to free memory
    gc()
  }
}

# Convert aggregated event study results to data.table for plotting
event_study_plot_data <- rbindlist(lapply(names(event_study_aggregated), function(name) {
  es <- event_study_aggregated[[name]]
  parts <- strsplit(name, "_")[[1]]
  payer_val <- parts[1]
  toc_val <- parts[2]

  data.table(
    payer = payer_val,
    toc = toc_val,
    rel_year_parsed = es$egt,
    estimate = es$att.egt,
    std.error = es$se.egt,
    conf.low = es$att.egt - 1.96 * es$se.egt,
    conf.high = es$att.egt + 1.96 * es$se.egt
  )
}))

cat("Callaway & Sant'Anna analysis complete.\n")

# ==============================================================================
# Event Study Figure for Paper
# ==============================================================================
p_event_study <- ggplot(event_study_plot_data,
                        aes(x = rel_year_parsed, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = -0.5, linetype = "dashed", color = "red", alpha = 0.5) +
  geom_line(color = "#0072B2", linewidth = 0.8) +
  geom_point(size = 2.5, color = "#0072B2") +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high),
                width = 0.2, color = "#0072B2", alpha = 0.6) +
  facet_wrap(toc ~ payer, scales = "free_y", nrow = 5) +
  labs(
    title = "Event Study: Effect of Medicaid Expansion on Health Care Spending",
    subtitle = paste("Outcome:", OUTCOME_VAR, "| Callaway & Sant'Anna (2021) estimator with not-yet-treated controls"),
    x = "Years Relative to Medicaid Expansion",
    y = ifelse(OUTCOME_VAR == "spend_per_capita_mean",
               "Effect on Spend per Capita ($)",
               "Effect on Spend per Beneficiary ($)"),
    caption = "Note: 95% confidence intervals shown. Standard errors clustered at state level.\nEstimator: Callaway & Sant'Anna (2021) doubly-robust DiD with not-yet-treated comparison group.\nTreatment: 2014 expanders only. Control: not-yet-treated states (never expanded + 2015+ expanders before treatment)."
  ) +
  scale_x_continuous(breaks = seq(-5, 5, 1)) +
  theme_bw() +
  theme(
    strip.text = element_text(size = 9, face = "bold"),
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11),
    plot.caption = element_text(hjust = 0, size = 8, color = "gray40"),
    panel.grid.minor = element_blank()
  )

ggsave("event_study_results.png", p_event_study, width = 14, height = 12, dpi = 300)
print("Event study plot saved to: event_study_results.png")

# ==============================================================================
# Summary: Overall ATT and Group-Specific ATT
# ==============================================================================
# Aggregate Callaway & Sant'Anna results to get overall ATT

cat("Computing overall ATT estimates...\n")

overall_att_results <- rbindlist(lapply(names(cs_results_list), function(name) {
  cs_result <- cs_results_list[[name]]
  parts <- strsplit(name, "_")[[1]]
  payer_val <- parts[1]
  toc_val <- parts[2]

  # Overall ATT (average across all post-treatment periods and groups)
  overall_agg <- aggte(cs_result, type = "simple")

  # Group-specific ATT (for 2014 cohort)
  group_agg <- aggte(cs_result, type = "group")

  data.table(
    payer = payer_val,
    toc = toc_val,
    overall_att = overall_agg$overall.att,
    overall_se = overall_agg$overall.se,
    overall_pval = 2 * pnorm(-abs(overall_agg$overall.att / overall_agg$overall.se)),
    group_2014_att = if(length(group_agg$att.egt) > 0) group_agg$att.egt[1] else NA_real_,
    group_2014_se = if(length(group_agg$se.egt) > 0) group_agg$se.egt[1] else NA_real_
  )
}))

# Format results table
overall_att_results[, `:=`(
  `Overall ATT` = sprintf("%.2f (%.2f)%s",
                          overall_att,
                          overall_se,
                          ifelse(overall_pval < 0.01, "***",
                                 ifelse(overall_pval < 0.05, "**",
                                        ifelse(overall_pval < 0.1, "*", "")))),
  `2014 Cohort ATT` = sprintf("%.2f (%.2f)",
                              group_2014_att,
                              group_2014_se)
)]

# Save results
fwrite(overall_att_results[, .(payer, toc, `Overall ATT`, `2014 Cohort ATT`)],
       "overall_att_results.csv")

# Create HTML table
att_table <- kable(overall_att_results[, .(payer, toc, `Overall ATT`, `2014 Cohort ATT`)],
                   format = "html",
                   caption = paste("Overall Average Treatment Effects on the Treated:", OUTCOME_VAR)) %>%
  kable_styling(bootstrap_options = c("striped", "hover")) %>%
  add_header_above(c(" " = 2, "ATT Estimates (SE)" = 2)) %>%
  footnote(general = "Callaway & Sant'Anna (2021) estimator with not-yet-treated comparison group. Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1",
           general_title = "Note:")

save_kable(att_table, "overall_att_results.html")
print("Overall ATT results saved to: overall_att_results.html and overall_att_results.csv")

# ==============================================================================
# Save full event study results
# ==============================================================================
fwrite(event_study_plot_data, "event_study_coefficients.csv")
print("Full event study coefficients saved to: event_study_coefficients.csv")

# Also save the overall ATT results
print("Overall ATT results:")
print(overall_att_results[, .(payer, toc, overall_att, overall_se, overall_pval)])

print("\n=== ANALYSIS COMPLETE ===")
print(paste("Method: Callaway & Sant'Anna (2021) doubly-robust DiD estimator"))
print(paste("Outcome variable used:", OUTCOME_VAR))
print(paste("Treatment group: States expanding in 2014 (N =",
            length(unique(dt[group == "Expanded 2014", location_name])), ")"))
print(paste("Control group: Not-yet-treated states (total N =",
            length(unique(dt[group != "Expanded 2014", location_name])), ")"))
print(paste("  - Never expanded (N =",
            length(unique(dt[group == "Never Expanded", location_name])), ")"))
print(paste("  - Later expanders (2015+) used as pre-treatment controls (N =",
            length(unique(dt[group == "Later Expansion", location_name])), ")"))
