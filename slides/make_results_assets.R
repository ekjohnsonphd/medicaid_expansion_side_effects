# Figures and LaTeX table fragments for slides/results_deck.tex
library(data.table); library(ggplot2)

NAVY<-"#2E4057"; TEAL<-"#048A81"; ORANGE<-"#E85D04"; PURPLE<-"#9D4EDD"
WGRAY<-"#6C757D"; LGRAY<-"#E9ECEF"; RED<-"#D62828"; GOLD<-"#D4A03A"; BG<-"#FAFAFA"
FIG<-"slides/figures_res"; TAB<-"slides/tables"

pcol <- c(mdcd=NAVY, mdcr=RED, priv=GOLD, oop=PURPLE)
plab <- c(mdcd="Medicaid", mdcr="Medicare", priv="Private", oop="Out-of-pocket")
tlab <- c(Total="All care", AM="Ambulatory", ED="Emergency", IP="Inpatient",
          NF="Nursing fac.", RX="Pharmacy")
olab <- c(coverage="Coverage (pp)", spend_per_capita="Spend per capita",
          spend_per_bene="Spend per enrollee", vol_per_capita="Volume per capita",
          vol_per_bene="Volume per enrollee", spend_per_vol="Price per unit")

base <- function(sz=9) theme_minimal(base_size=sz) +
  theme(plot.background=element_rect(fill=BG,colour=NA),
        panel.background=element_rect(fill=BG,colour=NA),
        panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour=LGRAY,linewidth=0.3),
        axis.title=element_text(colour=WGRAY,size=rel(0.85)),
        axis.text=element_text(colour=NAVY), legend.position="none",
        strip.text=element_text(colour=NAVY,face="bold",size=rel(0.9)),
        text=element_text(colour=NAVY))
sv <- function(p,f,w,h) ggsave(file.path(FIG,f),p,width=w,height=h,device="pdf")

es <- fread("results/components_event_study.csv")
ov <- fread("results/components_overall.csv")
es[, `:=`(lo=att-1.96*se, hi=att+1.96*se)]
MAIN <- function(d) d[basis=="allages" & est=="reg" & sample=="c2014"]

esplot <- function(d, facet, ylab) {
  ggplot(d[event_time %between% c(-4,4)], aes(event_time, att, colour=payer, fill=payer)) +
    geom_hline(yintercept=0, colour=WGRAY, linewidth=0.3) +
    geom_vline(xintercept=-0.5, colour=WGRAY, linetype="dashed", linewidth=0.3) +
    geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.16, colour=NA) +
    geom_line(linewidth=0.65) + geom_point(size=0.9) +
    scale_colour_manual(values=pcol) + scale_fill_manual(values=pcol) +
    scale_x_continuous(breaks=c(-4,-2,0,2,4)) +
    labs(x="Years relative to expansion", y=ylab) + base()
}

# 1. First stage: coverage by payer
d1 <- MAIN(es)[outcome=="coverage"]
d1[, pf := factor(plab[payer], levels=plab)]
sv(esplot(d1, NULL, "ATT, percentage points") + facet_wrap(~pf, nrow=1),
   "fs_coverage.pdf", 6.5, 2.2)

# 2. Medicaid, all six outcomes, all care
d2 <- MAIN(es)[payer=="mdcd" & toc=="Total"]
d2[, of := factor(olab[outcome], levels=olab)]
sv(esplot(d2, NULL, "ATT") + facet_wrap(~of, nrow=2, scales="free_y"),
   "mdcd_components.pdf", 6.5, 3.1)

# 3. Medicaid spend per capita by type of care
d3 <- MAIN(es)[payer=="mdcd" & outcome=="spend_per_capita"]
d3[, tf := factor(tlab[toc], levels=tlab)]
sv(esplot(d3, NULL, "ATT, $ per capita") + facet_wrap(~tf, nrow=2, scales="free_y"),
   "mdcd_bytoc.pdf", 6.5, 3.1)

# 4. All payers x all care: spend per capita
d4 <- MAIN(es)[outcome=="spend_per_capita" & toc=="Total"]
d4[, pf := factor(plab[payer], levels=plab)]
sv(esplot(d4, NULL, "ATT, $ per capita") + facet_wrap(~pf, nrow=1, scales="free_y"),
   "payers_spc.pdf", 6.5, 2.2)

# 5. All payers x all TOC grid, spend per capita
d5 <- MAIN(es)[outcome=="spend_per_capita"]
d5[, `:=`(pf=factor(plab[payer], levels=plab), tf=factor(tlab[toc], levels=tlab))]
sv(esplot(d5, NULL, "ATT, $ per capita") + facet_grid(tf~pf, scales="free_y"),
   "grid_spc.pdf", 6.5, 4.3)

# 6. Robustness: headline estimates across specification
r6 <- ov[outcome %chin% c("coverage","spend_per_capita","spend_per_bene") &
         toc=="Total" & payer %chin% c("mdcd","priv")]
r6[, `:=`(lo=overall_att-1.96*overall_se, hi=overall_att+1.96*overall_se,
          spec=paste0(est, " / ", ifelse(basis=="allages","all ages","std"),
                      " / ", ifelse(sample=="c2014","2014","all")))]
r6[, of := factor(olab[outcome], levels=olab)]
r6[, pf := factor(plab[payer], levels=plab)]
p6 <- ggplot(r6, aes(overall_att, spec, colour=payer)) +
  geom_vline(xintercept=0, colour=WGRAY, linewidth=0.3) +
  geom_errorbar(aes(xmin=lo, xmax=hi), orientation="y", width=0, linewidth=0.6) +
  geom_point(size=1.5) +
  facet_grid(pf~of, scales="free_x") +
  scale_colour_manual(values=pcol) +
  labs(x="Overall ATT (95% CI)", y=NULL) + base(8)
sv(p6, "robustness.pdf", 6.5, 3.4)

# 7. Pre-trend p-values across every model
ov[, spec := paste0(ifelse(basis=="allages","All ages","Standardized"), "\n",
                    ifelse(sample=="c2014","2014 cohort","All cohorts"))]
p7 <- ggplot(ov, aes(pre_p, spec, colour=sample)) +
  geom_vline(xintercept=0.05, colour=RED, linetype="dashed", linewidth=0.4) +
  geom_jitter(width=0, height=0.22, size=0.7, alpha=0.45) +
  scale_colour_manual(values=c(c2014=TEAL, all_cohorts=ORANGE)) +
  scale_x_continuous(limits=c(0,1)) +
  labs(x="Joint pre-trend test, p-value", y=NULL) +
  base() + theme(panel.grid.major.y=element_blank())
sv(p7, "pretrend.pdf", 6.5, 2.3)

# ---- LaTeX table fragments -------------------------------------------------
fmt <- function(a, s, stars = TRUE) {
  t  <- abs(a / s)
  st <- if (!stars) rep("", length(a)) else
        fifelse(t > 2.58, "***", fifelse(t > 1.96, "**", fifelse(t > 1.64, "*", "")))
  st[is.na(st)] <- ""
  sprintf("%s%s", formatC(a, format = "f", digits = 1, big.mark = ","), st)
}
sefmt <- function(s) sprintf("(%s)", formatC(s, format="f", digits=1, big.mark=","))

# Table 1: first stage, coverage, every estimator x basis x sample
t1 <- ov[outcome=="coverage"]
t1[, cell := paste0(fmt(overall_att, overall_se), " ", sefmt(overall_se))]
t1w <- dcast(t1, est + basis + sample ~ payer, value.var="cell")
lines <- c("\\begin{tabular}{@{}lll rrr@{}}", "\\toprule",
  "Estimator & Age basis & Sample & Medicaid & Medicare & Private \\\\", "\\midrule")
for (i in seq_len(nrow(t1w))) {
  r <- t1w[i]
  lines <- c(lines, sprintf("%s & %s & %s & %s & %s & %s \\\\", r$est,
    ifelse(r$basis=="allages","all ages","std"), ifelse(r$sample=="c2014","2014","all"),
    r$mdcd, r$mdcr, r$priv))
}
lines <- c(lines, "\\bottomrule", "\\end{tabular}")
writeLines(lines, file.path(TAB, "tab_firststage.tex"))

# Table 2: Medicaid, six outcomes x six settings, main spec
t2 <- MAIN(ov)[payer=="mdcd"]
t2[, cell := paste0(fmt(overall_att, overall_se), " ", sefmt(overall_se))]
t2w <- dcast(t2, outcome ~ toc, value.var="cell")
t2w <- t2w[match(names(olab), outcome)]
lines <- c("\\begin{tabular}{@{}l rrrrrr@{}}", "\\toprule",
  paste0("Outcome & ", paste(tlab, collapse=" & "), " \\\\"), "\\midrule")
for (i in seq_len(nrow(t2w))) {
  r <- t2w[i]; if (is.na(r$outcome)) next
  vals <- sapply(names(tlab), function(k) { v <- r[[k]]; if (is.null(v)||is.na(v)) "---" else v })
  lines <- c(lines, sprintf("%s & %s \\\\", olab[r$outcome], paste(vals, collapse=" & ")))
}
lines <- c(lines, "\\bottomrule", "\\end{tabular}")
writeLines(lines, file.path(TAB, "tab_mdcd.tex"))

# Table 3: spend per capita, all payers x settings
t3 <- MAIN(ov)[outcome=="spend_per_capita"]
t3[, cell := paste0(fmt(overall_att, overall_se), " ", sefmt(overall_se))]
t3w <- dcast(t3, payer ~ toc, value.var="cell")
t3w <- t3w[match(names(plab), payer)]
lines <- c("\\begin{tabular}{@{}l rrrrrr@{}}", "\\toprule",
  paste0("Payer & ", paste(tlab, collapse=" & "), " \\\\"), "\\midrule")
for (i in seq_len(nrow(t3w))) {
  r <- t3w[i]; if (is.na(r$payer)) next
  vals <- sapply(names(tlab), function(k) { v <- r[[k]]; if (is.null(v)||is.na(v)) "---" else v })
  lines <- c(lines, sprintf("%s & %s \\\\", plab[r$payer], paste(vals, collapse=" & ")))
}
lines <- c(lines, "\\bottomrule", "\\end{tabular}")
writeLines(lines, file.path(TAB, "tab_payers.tex"))

# Table 4: pre-trend pass rates
t4 <- ov[, .(n=.N, pass=sum(pre_p>=0.05, na.rm=TRUE)), by=.(basis, sample)]
t4[, pct := sprintf("%.0f\\%%", 100*pass/n)]
lines <- c("\\begin{tabular}{@{}ll rr@{}}", "\\toprule",
  "Age basis & Sample & Models & Pass pre-test \\\\", "\\midrule")
for (i in seq_len(nrow(t4))) { r <- t4[i]
  lines <- c(lines, sprintf("%s & %s & %d & %d (%s) \\\\",
    ifelse(r$basis=="allages","All ages","Standardized"),
    ifelse(r$sample=="c2014","2014 cohort","All cohorts"), r$n, r$pass, r$pct)) }
lines <- c(lines, "\\bottomrule", "\\end{tabular}")
writeLines(lines, file.path(TAB, "tab_pretrend.tex"))

# Table 5: summary by term, Medicaid vs private, all care
ORD <- c("coverage","spend_per_vol","vol_per_bene","spend_per_bene","spend_per_capita")
t5 <- MAIN(ov)[toc=="Total" & payer %chin% c("mdcd","priv") & outcome %chin% ORD]
t5[, cell := paste0(fmt(overall_att, overall_se), " ", sefmt(overall_se))]
t5w <- dcast(t5, outcome ~ payer, value.var="cell")
t5p <- dcast(t5, outcome ~ payer, value.var="pre_p")
t5w <- t5w[match(ORD, outcome)]; t5p <- t5p[match(ORD, outcome)]
rlab <- c(coverage="Coverage (pp)", spend_per_vol="Price per unit (\\$)",
          vol_per_bene="Volume per enrollee", spend_per_bene="Spend per enrollee (\\$)",
          spend_per_capita="Spend per capita (\\$)")
lines <- c("\\begin{tabular}{@{}l rr l@{}}", "\\toprule",
  "Term & Medicaid & Private & Pre-test \\\\", "\\midrule")
for (i in seq_len(nrow(t5w))) {
  r <- t5w[i]; pr <- t5p[i]
  fails <- c(if (pr$mdcd < 0.05) "Medicaid", if (pr$priv < 0.05) "private")
  note <- if (length(fails)) paste(paste(fails, collapse=" \\& "), "fails") else "both pass"
  if (r$outcome == "spend_per_capita") lines <- c(lines, "\\midrule")
  bold <- r$outcome == "spend_per_capita"
  wrap <- function(z) if (bold) paste0("\\textbf{", z, "}") else z
  lines <- c(lines, sprintf("%s & %s & %s & %s \\\\",
    wrap(rlab[r$outcome]), wrap(r$mdcd), wrap(r$priv), note))
}
lines <- c(lines, "\\bottomrule", "\\end{tabular}")
writeLines(lines, file.path(TAB, "tab_summary.tex"))

message("assets written")
