# Callaway & Sant'Anna estimates for each term of the spending decomposition.
# Writes results/components_{event_study,overall}.csv

source("R/prep_components.R")
library(did)

PANELS <- list(allages = prep_components("All ages"),
               stdized = prep_components("Age/sex-standardized"))

SAMPLES <- list(c2014       = function(d) d[expansion_year %chin% c("0","2014") | expansion_year %in% c(0, 2014)],
                all_cohorts = function(d) d)

ESTS <- list(reg = list(e = "reg", x = XF_MAIN),
             dr  = list(e = "dr",  x = XF_SENS),
             ipw = list(e = "ipw", x = XF_SENS))

fit <- function(d, y, est) {
  m <- try(suppressWarnings(att_gt(
    yname = y, tname = "year_id", idname = "id", gname = "expansion_year",
    data = d, control_group = "notyettreated", clustervars = "id",
    est_method = est$e, xformla = est$x)), silent = TRUE)
  if (inherits(m, "try-error")) return(NULL)
  dyn <- try(suppressWarnings(aggte(m, type = "dynamic")), silent = TRUE)
  smp <- try(suppressWarnings(aggte(m, type = "simple")), silent = TRUE)
  if (inherits(dyn, "try-error")) return(NULL)
  list(es = data.table(event_time = dyn$egt, att = dyn$att.egt, se = dyn$se.egt),
       overall = if (inherits(smp, "try-error")) c(NA, NA) else c(smp$overall.att, smp$overall.se),
       pre_p = if (is.null(m$Wpval)) NA_real_ else m$Wpval,
       n_na = sum(is.na(m$att) | is.na(m$se)))
}

OUTCOMES <- c("spend_per_capita", "spend_per_bene", "vol_per_capita",
              "vol_per_bene", "spend_per_vol")

grid <- CJ(basis = names(PANELS), sample = names(SAMPLES), est = names(ESTS),
           payer = c("all", "mdcd", "mdcr", "oop", "priv"),
           toc = c("Total", "AM", "ED", "IP", "NF", "RX"),
           outcome = OUTCOMES, unique = TRUE)
# Coverage is one series per payer; add it on the Total rows only.
covg <- unique(grid[toc == "Total"])[, outcome := "coverage"]
grid <- rbind(grid, unique(covg))
grid <- grid[!(payer == "oop" & outcome %chin% c("spend_per_bene", "vol_per_bene", "coverage"))]
# The all-payer row is spending only: volume and enrollees are not comparable
# across payers, so only per-capita spending is defined for it.
grid <- grid[!(payer == "all" & outcome != "spend_per_capita")]
grid[, mod := .I]

message("Fitting ", nrow(grid), " models...")
res <- vector("list", nrow(grid)); ov <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  g <- grid[i]
  d <- SAMPLES[[g$sample]](PANELS[[g$basis]][payer == g$payer & toc == g$toc])
  r <- fit(d, g$outcome, ESTS[[g$est]])
  if (is.null(r)) next
  res[[i]] <- cbind(g[, .(mod)], r$es)
  ov[[i]]  <- data.table(g, overall_att = r$overall[1], overall_se = r$overall[2],
                         pre_p = as.numeric(r$pre_p), n_na = r$n_na)
  if (i %% 200 == 0) message("  ", i, " / ", nrow(grid))
}

es <- merge(grid, rbindlist(res), by = "mod")
ov <- rbindlist(ov)
fwrite(es, "results/components_event_study.csv")
fwrite(ov, "results/components_overall.csv")
message("Converged: ", nrow(ov), " / ", nrow(grid))
