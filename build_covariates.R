# ==============================================================================
# Build State-Level Covariates Table (2010-2019)
# ==============================================================================

library(data.table)
library(tidyverse)
library(tidycensus)

Sys.setenv(CENSUS_API_KEY = "312711928b4d98123f48a8a1998b7f2a201f6d7d")

# State crosswalk
state_crosswalk <- data.table(
  state_name = c("Alabama","Alaska","Arizona","Arkansas","California","Colorado",
                 "Connecticut","Delaware","District of Columbia","Florida","Georgia",
                 "Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky",
                 "Louisiana","Maine","Maryland","Massachusetts","Michigan","Minnesota",
                 "Mississippi","Missouri","Montana","Nebraska","Nevada","New Hampshire",
                 "New Jersey","New Mexico","New York","North Carolina","North Dakota",
                 "Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina",
                 "South Dakota","Tennessee","Texas","Utah","Vermont","Virginia",
                 "Washington","West Virginia","Wisconsin","Wyoming"),
  state_abbr = c("AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID",
                 "IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO",
                 "MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA",
                 "RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY")
)

# ==============================================================================
# Fetch poverty and income (all years)
# ==============================================================================

get_poverty_income <- function(year) {
  message(paste("Fetching poverty/income for", year))
  survey_type <- if (year >= 2012) "acs1" else "acs5"
  acs_year <- if (year == 2010) 2010 else if (year == 2011) 2011 else year

  poverty <- get_acs(geography = "state",
                     variables = c(total = "B17001_001", below_poverty = "B17001_002"),
                     year = acs_year, survey = survey_type, output = "wide")

  income <- get_acs(geography = "state",
                    variables = "B19013_001",
                    year = acs_year, survey = survey_type)

  setDT(poverty); setDT(income)
  poverty[, poverty_rate := (below_povertyE / totalE) * 100]
  income[, median_hh_income := estimate]

  # Merge by GEOID to ensure correct matching
  result <- merge(poverty[, .(GEOID, state_name = NAME, poverty_rate)],
                  income[, .(GEOID, median_hh_income)],
                  by = "GEOID")
  result[, year := year]
  result[, GEOID := NULL]
  result
}

# ==============================================================================
# Fetch uninsured (2012+ only - B27001 not available in older 5-year ACS)
# ==============================================================================

get_uninsured <- function(year) {
  message(paste("Fetching uninsured for", year))

  # Uninsured variables from B27001: "No health insurance coverage" by age/sex
  unins_vars <- c(
    paste0("B27001_0", c("05","08","11","14","17","20","23","26","29")),
    paste0("B27001_0", c("33","36","39","42","45","48","51","54","57"))
  )

  detail <- get_acs(geography = "state",
                    variables = c("B27001_001", unins_vars),
                    year = year, survey = "acs1")
  setDT(detail)

  totals <- detail[variable == "B27001_001", .(GEOID, NAME, total = estimate)]
  unins <- detail[variable != "B27001_001", .(uninsured = sum(estimate)), by = .(GEOID, NAME)]
  result <- merge(totals, unins, by = c("GEOID", "NAME"))
  result[, .(state_name = NAME, year = year, uninsured_rate = (uninsured / total) * 100)]
}

# ==============================================================================
# Fetch age demographics (proportion <= 18 and >= 65)
# ==============================================================================

get_age_demographics <- function(year) {
  message(paste("Fetching age demographics for", year))
  survey_type <- if (year >= 2012) "acs1" else "acs5"
  acs_year <- if (year == 2010) 2010 else if (year == 2011) 2011 else year

  # B01001: Sex by Age
  # Under 18: Males (003-006) + Females (027-030)
  # 65+: Males (020-025) + Females (044-049)
  under18_vars <- c(
    paste0("B01001_00", 3:6),   # Male: <5, 5-9, 10-14, 15-17
    paste0("B01001_0", 27:30)   # Female: <5, 5-9, 10-14, 15-17
  )

  over65_vars <- c(
    paste0("B01001_0", 20:25),  # Male: 65-66, 67-69, 70-74, 75-79, 80-84, 85+
    paste0("B01001_0", 44:49)   # Female: 65-66, 67-69, 70-74, 75-79, 80-84, 85+
  )

  all_vars <- c("B01001_001", under18_vars, over65_vars)

  detail <- get_acs(geography = "state",
                    variables = all_vars,
                    year = acs_year, survey = survey_type)
  setDT(detail)

  totals <- detail[variable == "B01001_001", .(GEOID, NAME, total_pop = estimate)]
  under18 <- detail[variable %in% under18_vars, .(pop_under18 = sum(estimate)), by = .(GEOID, NAME)]
  over65 <- detail[variable %in% over65_vars, .(pop_over65 = sum(estimate)), by = .(GEOID, NAME)]

  result <- merge(totals, under18, by = c("GEOID", "NAME"))
  result <- merge(result, over65, by = c("GEOID", "NAME"))
  result[, `:=`(
    prop_under18 = pop_under18 / total_pop,
    prop_over65 = pop_over65 / total_pop
  )]
  result[, .(state_name = NAME, year = year, prop_under18, prop_over65)]
}

# ==============================================================================
# Build dataset
# ==============================================================================

years <- 2010:2019

# Get poverty/income for all years
pov_inc <- rbindlist(lapply(years, get_poverty_income))

# Get uninsured for 2012+ only
unins <- rbindlist(lapply(2012:2019, get_uninsured))

# Get age demographics for all years
age_demo <- rbindlist(lapply(years, get_age_demographics))

# Merge
covariates <- merge(pov_inc, unins, by = c("state_name", "year"), all.x = TRUE)
covariates <- merge(covariates, age_demo, by = c("state_name", "year"), all.x = TRUE)
setnames(covariates,c("year","state_name"),c("year_id","location_name"))
# covariates <- merge(covariates, state_crosswalk, by = "state_name")

# setcolorder(covariates, c("state_abbr", "state_name", "year"))
# setorder(covariates, state_abbr, year)

# Save
fwrite(covariates, "data/state_covariates_2010_2019.csv")
message("Saved to data/state_covariates_2010_2019.csv")

# ==============================================================================
# Diagnostic plots
# ==============================================================================

national_avg <- covariates[, .(
  poverty_rate = mean(poverty_rate, na.rm = TRUE),
  median_hh_income = mean(median_hh_income, na.rm = TRUE),
  uninsured_rate = mean(uninsured_rate, na.rm = TRUE),
  prop_under18 = mean(prop_under18, na.rm = TRUE),
  prop_over65 = mean(prop_over65, na.rm = TRUE)
), by = year_id]

p1 <- ggplot(national_avg, aes(x = year_id, y = poverty_rate)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Average State Poverty Rate", y = "Poverty Rate (%)", x = "Year") +
  theme_minimal()

p2 <- ggplot(national_avg, aes(x = year_id, y = median_hh_income)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Average State Median HH Income", y = "Income ($)", x = "Year") +
  scale_y_continuous(labels = scales::comma) +
  theme_minimal()

p3 <- ggplot(national_avg[!is.na(uninsured_rate)], aes(x = year_id, y = uninsured_rate)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Average State Uninsured Rate (2012+)", y = "Uninsured (%)", x = "Year") +
  theme_minimal()

p4 <- ggplot(national_avg, aes(x = year_id, y = prop_under18)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Average State Proportion Under 18", y = "Proportion", x = "Year") +
  theme_minimal()

p5 <- ggplot(national_avg, aes(x = year_id, y = prop_over65)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Average State Proportion 65+", y = "Proportion", x = "Year") +
  theme_minimal()

p6 <- ggplot(covariates, aes(x = year_id, y = poverty_rate, group = location_name)) +
  geom_line(alpha = 0.3) +
  geom_line(data = national_avg, aes(group = 1), color = "red", linewidth = 1.5) +
  labs(title = "Poverty Rate by State (red = national avg)", y = "Poverty Rate (%)", x = "Year") +
  theme_minimal()

p7 <- ggplot(covariates, aes(x = year_id, y = median_hh_income, group = location_name)) +
  geom_line(alpha = 0.3) +
  geom_line(data = national_avg, aes(group = 1), color = "red", linewidth = 1.5) +
  labs(title = "Median HH Income by State (red = national avg)", y = "Income ($)", x = "Year") +
  scale_y_continuous(labels = scales::comma) +
  theme_minimal()

p8 <- ggplot(covariates[!is.na(uninsured_rate)], aes(x = year_id, y = uninsured_rate, group = location_name)) +
  geom_line(alpha = 0.3) +
  geom_line(data = national_avg[!is.na(uninsured_rate)], aes(group = 1), color = "red", linewidth = 1.5) +
  labs(title = "Uninsured Rate by State (red = national avg)", y = "Uninsured (%)", x = "Year") +
  theme_minimal()

pdf("results/covariates_trends.pdf", width = 10, height = 8)
print(p1); print(p2); print(p3); print(p4); print(p5)
print(p6); print(p7); print(p8)
dev.off()

message("Diagnostic plots saved to results/covariates_trends.pdf")

# ==============================================================================
# Hospital beds per capita: Download from KFF
# https://www.kff.org/other/state-indicator/beds-by-ownership/
# ==============================================================================
