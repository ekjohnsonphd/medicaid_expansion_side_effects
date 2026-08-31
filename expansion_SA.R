library(data.table)
library(tidyverse)
library(arrow)
library(fixest)  # Sun & Abraham (2021) via sunab()
library(broom)
library(kableExtra)

# Choose one: "spend_per_capita_mean" or "spend_per_bene_mean"
OUTCOME_VAR <- "spend_per_bene_mean"

# ==============================================================================
# Load and prepare data
# ==============================================================================
dt <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV")
medicaid_expansion <- fread("data/medicaid_expansion_cohorts.csv")

covariates <- fread("data/state_covariates_2010_2019.csv")

# Filter to age-standardized and specific types of care
dt <- dt[age_name == "Age/sex-standardized" & toc %in% c("AM","ED","IP","NF","RX")]
dt[, id := as.numeric(as.factor(location_name))]
dt <- merge(dt, medicaid_expansion[, .(location_name, expansion_year)],
            by = "location_name", all.x = TRUE)
dt <- merge(dt, covariates, by = c("location_name","year_id"))
dt[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]), by = location_name]

dt[, expansion_year := as.numeric(expansion_year)]
dt[is.na(expansion_year), expansion_year := 0]

# For Sun & Abraham: never-treated states need expansion_year = Inf (or large number)
# This tells sunab() to use them as the control group
dt[, cohort := fifelse(expansion_year == 0, Inf, expansion_year)]
dt <- dt[year_id <= 2018]
dt[cohort == 2019, cohort := Inf]
# ==============================================================================
# Test model: IP Medicare spending
# ==============================================================================
test <- dt[toc == "IP" & payer == "mdcr"]

t_model <- feols(
  spend_per_capita_mean ~ sunab(cohort, year_id) +
    poverty_rate + median_hh_income + ave_prior_uninsured + prop_under18 + prop_over65 |
    id + year_id,
  data = test,
  cluster = ~id
)

summary(t_model)
iplot(t_model, main = "Sun & Abraham Event Study: IP Medicare Spending")

# Aggregate ATT (average across all post-treatment periods)
summary(t_model, agg = "ATT")

# ==============================================================================
# Run all payer/toc/outcome combinations
# ==============================================================================
outcomes <- c("spend_per_bene_mean", "spend_per_capita_mean",
              "vol_per_capita_mean", "vol_per_bene_mean")
matrix <- as.data.table(expand(dt, payer, toc, outcomes))
matrix <- matrix[!(payer == "oop" & (outcomes %in% c("spend_per_bene_mean", "vol_per_bene_mean")))]

# Store results for summary table
all_results <- list()

pdf("results/jan22_SA_all_event_studies.pdf", onefile = TRUE)
for (i in 1:nrow(matrix)) {
  print(matrix[i])
  tdt <- dt[toc == matrix[i]$toc & payer == matrix[i]$payer]

  # Build formula dynamically
  fml <- as.formula(paste0(
    matrix[i]$outcomes,
    " ~ sunab(cohort, year_id) + poverty_rate + median_hh_income + ",
    "ave_prior_uninsured + prop_under18 + prop_over65 | id + year_id"
  ))

  t_model <- tryCatch({
    feols(fml, data = tdt, cluster = ~id)
  }, error = function(e) {
    message("Error for ", paste0(matrix[i], collapse = " | "), ": ", e$message)
    return(NULL)
  })

  if (!is.null(t_model)) {
    # Store aggregated ATT using fixest's aggregation
    agg_model <- summary(t_model, agg = "ATT")
    agg_coef <- coeftable(agg_model)
    all_results[[i]] <- data.table(
      payer = matrix[i]$payer,
      toc = matrix[i]$toc,
      outcome = matrix[i]$outcomes,
      att = agg_coef[1, "Estimate"],
      se = agg_coef[1, "Std. Error"],
      pval = agg_coef[1, "Pr(>|t|)"]
    )

    # Plot event study
    p <- iplot(t_model, main = paste0(matrix[i], collapse = " | "))
    print(p)
  }
}
dev.off()

# Combine and save overall ATT results
overall_att <- rbindlist(all_results)
fwrite(overall_att, "results/overall_att_SA_results.csv")

# Create HTML table of results
overall_att[, sig := fifelse(pval < 0.01, "***",
                     fifelse(pval < 0.05, "**",
                     fifelse(pval < 0.1, "*", "")))]
overall_att[, estimate := sprintf("%.3f%s (%.3f)", att, sig, se)]

att_wide <- dcast(overall_att, payer + toc ~ outcome, value.var = "estimate")
att_wide %>%
  kbl(caption = "Sun & Abraham Overall ATT Estimates by Payer, Type of Care, and Outcome") %>%
  kable_styling(bootstrap_options = c("striped", "hover")) %>%
  save_kable("results/overall_att_SA_results.html")

# ==============================================================================
# 2014 early expanders only (using never-treated as control)
# ==============================================================================
pdf("results/jan22_SA_event_studies_2014.pdf", onefile = TRUE)
for (i in 1:nrow(matrix)) {
  print(matrix[i])
  tdt <- dt[toc == matrix[i]$toc & payer == matrix[i]$payer]

  # Keep only 2014 expanders and never-treated
  tdt <- tdt[expansion_year %in% c(0, 2014)]
  tdt[, cohort_2014 := fifelse(expansion_year == 2014, 2014, Inf)]

  fml <- as.formula(paste0(
    matrix[i]$outcomes,
    " ~ sunab(cohort_2014, year_id) + poverty_rate + median_hh_income + ",
    "ave_prior_uninsured + prop_under18 + prop_over65 | id + year_id"
  ))

  t_model <- tryCatch({
    feols(fml, data = tdt, cluster = ~id)
  }, error = function(e) {
    message("Error for ", paste0(matrix[i], collapse = " | "), ": ", e$message)
    return(NULL)
  })

  if (!is.null(t_model)) {
    p <- iplot(t_model, main = paste0("2014 Expanders: ", paste0(matrix[i], collapse = " | ")))
    print(p)
  }
}
dev.off()
