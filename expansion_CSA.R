library(data.table)
library(tidyverse)
library(arrow)
library(did)  # Callaway & Sant'Anna (2021) package
library(modelsummary)
library(broom)
library(kableExtra)

date_string <- "jan28"

# Choose one: "spend_per_capita_mean" or "spend_per_bene_mean"
OUTCOME_VAR <- "spend_per_bene_mean"

# ==============================================================================
# Load and prepare data
# ==============================================================================
dt <- fread("data/dex/IHME_USA_HEALTH_CARE_SPENDING_CAUSE_COUNTY_2010_2019_STATE_NATIONAL_TOC_PAYER_2010_2019_Y2025M02D13.CSV")
medicaid_expansion <- fread("data/medicaid_expansion_raw_data.csv")
colnames(medicaid_expansion) <- c("location_name","expansion","expansion_year","restricted")

covariates <- fread("data/state_covariates_2010_2019.csv")
# cov list: poverty_rate,median_hh_income,uninsured_rate,prop_under18,prop_over65,ave_prior_uninsured

state_crosswalk <- data.table(
  location_name = c("Alabama","Alaska","Arizona","Arkansas","California","Colorado",
                 "Connecticut","Delaware","District of Columbia","Florida","Georgia",
                 "Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky",
                 "Louisiana","Maine","Maryland","Massachusetts","Michigan","Minnesota",
                 "Mississippi","Missouri","Montana","Nebraska","Nevada","New Hampshire",
                 "New Jersey","New Mexico","New York","North Carolina","North Dakota",
                 "Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina",
                 "South Dakota","Tennessee","Texas","Utah","Vermont","Virginia",
                 "Washington","West Virginia","Wisconsin","Wyoming"),
  state = c("AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID",
                 "IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO",
                 "MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA",
                 "RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY")
)

# Filter to age-standardized and specific types of care
dt <- dt[age_name == "Age/sex-standardized" & toc %in% c("AM","ED","IP","NF","RX","All toc")]
dt[, id := as.numeric(as.factor(location_name))]
dt <- merge(dt, medicaid_expansion[, .(location_name, expansion_year, restricted)],
            by = "location_name", all.x = TRUE)
dt <- merge(dt, covariates, by = c("location_name","year_id"))
dt[, ave_prior_uninsured := mean(uninsured_rate[year_id %in% c(2012, 2013)]), by = location_name]

dt[, expansion_year := as.numeric(expansion_year)]
dt[is.na(expansion_year), expansion_year := 0]
# dt <- dt[year_id <= 2018]

dt_agg <- dt[, lapply(.SD, sum), 
  by = setdiff(colnames(dt), str_subset(colnames(dt),"spend|vol|toc")), 
  .SDcols = str_subset(colnames(dt),"spend|vol")]

dt_agg[, toc := "All TOC"]
dt <- rbind(dt, dt_agg)
dt[, expanded := 0]
dt[(expansion_year != 0) & (year_id >= expansion_year), expanded := 1]
dt <- dt[state_crosswalk, on = "location_name"]

dt |> 
  group_by(payer, toc) |> 
  write_csv_dataset("data/analysis/model_data/")


test <- dt[toc == "IP" & payer == "mdcr"]
t_model <- att_gt(
        yname = "spend_per_capita_mean",
        tname = "year_id",
        idname = "id",
        gname = "expansion_year",
        data = test,
        control_group = "notyettreated",
        clustervars = "id",
        est_method = "reg",
        xformla = ~ poverty_rate + median_hh_income + ave_prior_uninsured + prop_under18 + prop_over65  # ~baseline_spending + population
      )

summary(t_model)
ggdid(t_model)

t_es <- aggte(t_model, type = "dynamic")
summary(t_es)
ggdid(t_es)

outcomes <- c("spend_per_bene_mean", "spend_per_capita_mean",
              "vol_per_capita_mean", "vol_per_bene_mean", "spend_per_vol_mean")
matrix <- as.data.table(expand(dt, payer, toc, outcomes))
matrix <- matrix[!(payer == "oop" & (outcomes %in% c("spend_per_bene_mean", "vol_per_bene_mean")))]
matrix[, toc := factor(toc, levels = c("All TOC", "AM", "ED", "IP", "NF", "RX"))]
matrix[, model := paste(payer, toc, outcomes, sep = "|")]
matrix[, mod := .I]
setorder(matrix, payer, toc, outcomes)

# dt <- dt[restricted != "Yes"]

models <- lapply(1:nrow(matrix), function(i){
  sub_dt <- copy(dt)[payer == matrix[i]$payer & toc == matrix[i]$toc]
  print(matrix[i])
  t_model <- att_gt(
        yname = matrix[i]$outcomes,
        tname = "year_id",
        idname = "id",
        gname = "expansion_year",
        data = sub_dt,
        control_group = "notyettreated",
        clustervars = "id",
        est_method = "ipw",
        xformla = ~poverty_rate + median_hh_income + ave_prior_uninsured + prop_under18 + prop_over65
      )
  return(t_model)
})

agg_models <- lapply(models, aggte, type = "dynamic")

agg_results <- lapply(1:length(agg_models), function(i){
  model_obj <- agg_models[[i]]
  sdt <- data.table(index = model_obj$egt, att = model_obj$att.egt, se = model_obj$se.egt)
  sdt[, lower := att - 1.96*se][, upper := att + 1.96*se]
  sdt[, exposure_time := ifelse(index >= 0, "Post", "Pre")]
  sdt[, mod := i]
  return(sdt)
}) %>% rbindlist()
agg_results <- merge(matrix, agg_results, by = "mod")

# ==============================================================================
# Plot event study results
# ==============================================================================
dir.create("results/event_study_plots/", showWarnings = FALSE, recursive = TRUE)

plot_event_study <- function(data, outcome_var, title) {
  p <- ggplot(data[outcomes == outcome_var]) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_pointrange(aes(x = index, y = att, ymin = lower, ymax = upper,
                        shape = exposure_time, color = payer),
                    position = position_dodge(width = 0.4),
                    alpha = 0.8, size = 0.5, linewidth = 0.6) +
    xlim(c(-4.5, 4.5)) +
    scale_shape_manual(values = c(19, 1)) +
    scale_color_manual(values = c("mdcd" = "#E41A1C", "mdcr" = "#377EB8",
                                  "priv" = "#4DAF4A", "oop" = "#984EA3"),
                       labels = c("mdcd" = "Medicaid", "mdcr" = "Medicare",
                                  "priv" = "Private", "oop" = "Out-of-pocket")) +
    facet_wrap(~toc, scales = "free_y") +
    theme_minimal(base_size = 12) +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold")
    ) +
    labs(color = "Payer", shape = "Period",
         y = "ATT Estimate", x = "Years Since Expansion",
         title = title)

  ggsave(paste0("results/event_study_plots/", outcome_var, ".png"),
         plot = p, width = 10, height = 7, dpi = 300, bg = "white")
  return(p)
}

plot_event_study(agg_results, "spend_per_bene_mean", "Spending per Beneficiary")
plot_event_study(agg_results, "spend_per_capita_mean", "Spending per Capita")
plot_event_study(agg_results, "vol_per_bene_mean", "Volume per Beneficiary")
plot_event_study(agg_results, "vol_per_capita_mean", "Volume per Capita")
plot_event_study(agg_results, "spend_per_vol_mean", "Spending per Volume")
