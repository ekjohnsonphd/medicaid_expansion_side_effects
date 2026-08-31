# Size of the Callaway-Sant'Anna joint pre-trend test as a function of
# treated-cohort size.
#
# Among states that NEVER expanded, label k of them as a fake cohort.
# There is no treatment, so any rejection of the pre-test is a false positive.
# A correctly sized test rejects 5% of the time regardless of k.
source("R/prep_components.R"); suppressMessages(library(did))
p <- prep_components("All ages")
d <- p[payer=="mdcd" & toc=="Total" & expansion_year == 0]
states <- unique(d$location_name)
cat("never-treated states available:", length(states), "\n\n")

set.seed(20260831)
REPS <- 200
res <- rbindlist(lapply(c(1, 2, 3, 6, 10), function(k) {
  pv <- replicate(REPS, {
    fake <- sample(states, k)
    dd <- copy(d)[, expansion_year := fifelse(location_name %chin% fake, 2016, 0)]
    m <- try(suppressWarnings(att_gt(yname="spend_per_capita", tname="year_id",
      idname="id", gname="expansion_year", data=dd, control_group="notyettreated",
      clustervars="id", est_method="reg", xformla=XF_MAIN)), silent=TRUE)
    if (inherits(m,"try-error") || is.null(m$Wpval)) NA_real_ else m$Wpval
  })
  data.table(k = k, reps = sum(!is.na(pv)),
             reject_5pct = round(100*mean(pv < 0.05, na.rm=TRUE), 1),
             median_p = round(median(pv, na.rm=TRUE), 3))
}))
cat("=== false-positive rate of the joint pre-trend test ===\n")
cat("   (no treatment exists; a correct test rejects 5% of the time)\n\n")
print(res)


# Same design, but recording whether the ATT itself comes out significant.
res_att <- rbindlist(lapply(c(1, 3, 6, 10), function(k) {
  out <- replicate(REPS, {
    fake <- sample(states, k)
    dd <- copy(d)[, expansion_year := fifelse(location_name %chin% fake, 2016, 0)]
    m <- try(suppressWarnings(att_gt(yname="spend_per_capita", tname="year_id",
      idname="id", gname="expansion_year", data=dd, control_group="notyettreated",
      clustervars="id", est_method="reg", xformla=XF_MAIN)), silent=TRUE)
    if (inherits(m,"try-error")) return(c(NA,NA))
    s <- try(suppressWarnings(aggte(m, type="simple")), silent=TRUE)
    if (inherits(s,"try-error")) return(c(NA,NA))
    c(s$overall.att, s$overall.se)
  })
  data.table(k = k, reps = sum(!is.na(out[1,])),
             att_sig_5pct = round(100*mean(abs(out[1,]/out[2,]) > 1.96, na.rm=TRUE), 1))
}))
cat("\n=== false-positive rate of the ATT itself ===\n\n")
print(res_att)

fwrite(merge(res, res_att, by = c("k", "reps"), all = TRUE),
       "results/pretest_placebo.csv")
