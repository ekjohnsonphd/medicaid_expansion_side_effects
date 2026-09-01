# Figures for poster/poster.tex (A0 portrait).
# Text is sized for ~1 m viewing: base_size 26+ at roughly 1:1 print scale.
library(data.table); library(ggplot2)
source("R/prep_components.R")

NAVY<-"#2E4057"; TEAL<-"#048A81"; ORANGE<-"#E85D04"; PURPLE<-"#9D4EDD"
WGRAY<-"#6C757D"; LGRAY<-"#DDE2E6"; RED<-"#D62828"; GOLD<-"#D4A03A"; BG<-"#FFFFFF"
OUT <- "poster/figures"

plab <- c(mdcd="Medicaid", mdcr="Medicare", priv="Private", oop="Out-of-pocket")
tlab <- c(Total="All care", AM="Ambulatory", ED="Emergency", IP="Inpatient",
          NF="Nursing fac.", RX="Pharmacy")
pcol <- c(mdcd=TEAL, mdcr=RED, priv=GOLD, oop=PURPLE)

pbase <- function(sz=26) theme_minimal(base_size=sz) +
  theme(plot.background=element_rect(fill=BG,colour=NA),
        panel.background=element_rect(fill=BG,colour=NA),
        panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour=LGRAY,linewidth=0.5),
        axis.title=element_text(colour=WGRAY),
        axis.text=element_text(colour=NAVY),
        strip.text=element_text(colour=NAVY,face="bold"),
        legend.position="none", text=element_text(colour=NAVY))
sv <- function(p,f,w,h) ggsave(file.path(OUT,f),p,width=w,height=h,device="pdf")

# Pre-expansion levels in treated states, for normalising to percent
p <- prep_components("All ages")[expansion_year %in% c(0,2014)]
pre <- p[expansion_year==2014 & year_id<=2013,
   .(spend=sum(spend,na.rm=TRUE), vol=sum(vol,na.rm=TRUE),
     bene=sum(bene,na.rm=TRUE), pop=sum(pop_ref)), by=.(payer,toc)]
pre[, `:=`(spend_per_capita=spend/pop, spend_per_bene=fifelse(bene>0,spend/bene,NA_real_),
           coverage=fifelse(bene>0,100*bene/pop,NA_real_))]
pl <- melt(pre, id.vars=c("payer","toc"),
           measure.vars=c("spend_per_capita","spend_per_bene","coverage"),
           variable.name="outcome", value.name="base")

ov <- fread("results/components_overall.csv")[basis=="allages" & est=="reg" & sample=="c2014"]
es <- fread("results/components_event_study.csv")[basis=="allages" & est=="reg" & sample=="c2014"]
r  <- merge(ov, pl, by=c("payer","toc","outcome"))
r[, `:=`(pct=100*overall_att/base,
         lo=100*(overall_att-1.96*overall_se)/base,
         hi=100*(overall_att+1.96*overall_se)/base)]

# --- 1. First stage: coverage ----------------------------------------------
d1 <- es[outcome=="coverage" & toc=="Total" & event_time %between% c(-4,4)]
d1[, pf := factor(plab[payer], levels=plab)]
d1[, `:=`(lo=att-1.96*se, hi=att+1.96*se)]
sv(ggplot(d1, aes(event_time, att, colour=payer, fill=payer)) +
   geom_hline(yintercept=0, colour=WGRAY, linewidth=0.6) +
   geom_vline(xintercept=-0.5, colour=WGRAY, linetype="dashed", linewidth=0.6) +
   geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.18, colour=NA) +
   geom_line(linewidth=1.6) + geom_point(size=3) +
   facet_wrap(~pf, nrow=1) +
   scale_colour_manual(values=pcol) + scale_fill_manual(values=pcol) +
   scale_x_continuous(breaks=c(-4,-2,0,2,4)) +
   labs(x="Years relative to expansion", y="Change in coverage\n(percentage points)") +
   pbase(26), "fig_coverage.pdf", 11.5, 5.4)

# --- 2. THE NULL: per-capita spending, every payer and setting --------------
d2 <- r[outcome=="spend_per_capita" & payer %chin% names(plab)]
d2[, `:=`(pf=factor(plab[payer], levels=plab), tf=factor(tlab[toc], levels=rev(tlab)))]
sv(ggplot(d2, aes(pct, tf, colour=payer)) +
   geom_vline(xintercept=0, colour=NAVY, linewidth=0.8) +
   geom_errorbar(aes(xmin=lo, xmax=hi), orientation="y", width=0, linewidth=1.6) +
   geom_point(size=4.5) +
   facet_wrap(~pf, nrow=1) +
   scale_colour_manual(values=pcol) +
   scale_x_continuous(breaks=c(-30,0,30)) +
   labs(x="Effect on per-capita spending (% of pre-expansion level)", y=NULL) +
   pbase(26), "fig_null.pdf", 11.5, 8.2)

# --- 3. Private: per enrollee vs per capita ---------------------------------
d3 <- r[payer=="priv" & outcome %chin% c("spend_per_bene","spend_per_capita")]
d3[, `:=`(tf=factor(tlab[toc], levels=rev(tlab)),
          of=factor(c(spend_per_bene="Per enrollee", spend_per_capita="Per capita")[outcome],
                    levels=c("Per enrollee","Per capita")))]
sv(ggplot(d3, aes(pct, tf)) +
   geom_vline(xintercept=0, colour=NAVY, linewidth=0.8) +
   geom_errorbar(aes(xmin=lo, xmax=hi), orientation="y", width=0, linewidth=1.6, colour=GOLD) +
   geom_point(size=4.5, colour=GOLD) +
   facet_wrap(~of, nrow=1) +
   scale_x_continuous(breaks=scales::breaks_pretty(4)) +
   labs(x="Effect on private spending (% of pre-expansion level)", y=NULL) +
   pbase(26), "fig_private.pdf", 11.5, 6.0)

# --- numbers used in the text ----------------------------------------------
key <- r[toc=="Total" & outcome=="spend_per_capita",
         .(payer, att=round(overall_att,1), pct=round(pct,1),
           lo=round(lo,1), hi=round(hi,1))]
fwrite(key, "poster/key_numbers.csv")
print(key)
cov <- ov[outcome=="coverage", .(payer, att=round(overall_att,2), se=round(overall_se,2),
        pre=round(pre_p,3))]
print(cov)
message("poster figures written")
