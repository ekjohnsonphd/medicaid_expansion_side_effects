# Assets for slides/survey_deck.tex -- every outcome, raw and estimated.
# Sample is fixed to the 2014 expansion cohort throughout.
library(data.table); library(ggplot2)
source("R/prep_components.R")

NAVY<-"#2E4057"; TEAL<-"#048A81"; ORANGE<-"#E85D04"; PURPLE<-"#9D4EDD"
WGRAY<-"#6C757D"; LGRAY<-"#E9ECEF"; RED<-"#D62828"; GOLD<-"#D4A03A"; BG<-"#FAFAFA"
FIG<-"slides/figures_survey"; TAB<-"slides/tables"

plab <- c(all="All payers", mdcd="Medicaid", mdcr="Medicare", priv="Private", oop="Out-of-pocket")
tlab <- c(Total="All care", AM="Ambulatory", ED="Emergency", IP="Inpatient",
          NF="Nursing fac.", RX="Pharmacy")
rlab <- c(coverage="Coverage", spend_per_capita="Spend/capita",
          spend_per_bene="Spend/enrollee", vol_per_capita="Vol/capita",
          vol_per_bene="Vol/enrollee", spend_per_vol="Price/unit")
slab <- c(Total="All care", AM="Ambul.", ED="Emerg.", IP="Inpat.",
          NF="Nursing", RX="Pharm.")
olab <- c(coverage="Coverage (pp)", spend_per_capita="Spend per capita ($)",
          spend_per_bene="Spend per enrollee ($)", vol_per_capita="Volume per 1,000 residents",
          vol_per_bene="Volume per 1,000 enrollees", spend_per_vol="Price per unit ($)")
pcol <- c(all=NAVY, mdcd=TEAL, mdcr=RED, priv=GOLD, oop=PURPLE)
gcol <- c(`2014 expanders`=TEAL, `Never expanded`=ORANGE)

base <- function(sz=8) theme_minimal(base_size=sz) +
  theme(plot.background=element_rect(fill=BG,colour=NA),
        panel.background=element_rect(fill=BG,colour=NA),
        panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour=LGRAY,linewidth=0.28),
        axis.title=element_text(colour=WGRAY,size=rel(0.85)),
        axis.text=element_text(colour=NAVY,size=rel(0.8)), legend.position="none",
        strip.text=element_text(colour=NAVY,face="bold",size=rel(0.85)),
        text=element_text(colour=NAVY))
sv <- function(p,f,w,h) ggsave(file.path(FIG,f),p,width=w,height=h,device="pdf")

# ---------------- raw group trends -----------------------------------------
p <- prep_components("All ages")
p <- p[expansion_year %in% c(0, 2014)]
p[, grp := fifelse(expansion_year==2014, "2014 expanders", "Never expanded")]

# Population-weighted group means, rebuilt from totals so ratios stay correct.
raw <- p[, .(spend=sum(spend, na.rm=TRUE), vol=sum(vol, na.rm=TRUE),
             bene=sum(bene, na.rm=TRUE), pop=sum(pop_ref)),
         by=.(grp, year_id, payer, toc)]
raw[, `:=`(spend_per_capita = spend/pop,
           spend_per_bene   = fifelse(bene>0, spend/bene, NA_real_),
           vol_per_capita   = fifelse(vol>0, vol/pop*1000, NA_real_),
           vol_per_bene     = fifelse(vol>0 & bene>0, vol/bene*1000, NA_real_),
           spend_per_vol    = fifelse(vol>0, spend/vol, NA_real_),
           coverage         = fifelse(bene>0, 100*bene/pop, NA_real_))]

# Each outcome gets two views: "all care" across payers (readable), and the
# five clinical settings (detail). A single 6x5 grid is too dense to read.
raw_fig <- function(outc, which = c("total","grid")) {
  which <- match.arg(which)
  d <- raw[!is.na(get(outc)) & payer %chin% names(plab)]
  d <- if (which == "total") d[toc == "Total"] else d[toc != "Total"]
  if (!nrow(d)) return(NULL)
  LB <- if (which == "grid") slab else tlab
  d[, `:=`(pf=factor(plab[payer], levels=plab), tf=factor(LB[toc], levels=LB))]
  g <- ggplot(d, aes(year_id, get(outc), colour=grp)) +
    geom_vline(xintercept=2013.5, colour=WGRAY, linetype="dashed", linewidth=0.3) +
    geom_line(linewidth=0.6) + geom_point(size=0.8) +
    scale_colour_manual(values=gcol) +
    scale_x_continuous(breaks=if (which == "grid") c(2012, 2016) else c(2010, 2014, 2018)) +
    scale_y_continuous(n.breaks=3) +
    labs(x=NULL, y=olab[outc])
  if (which == "total") g + facet_wrap(~pf, nrow=1, scales="free_y") + base(10)
  else g + facet_grid(tf~pf, scales="free_y") + base(9) +
       scale_y_continuous(n.breaks=3) + labs(y=NULL) +
       theme(strip.text.y = element_text(angle = 0, hjust = 0))
}
for (o in names(olab)) {
  a <- raw_fig(o, "total"); if (!is.null(a)) sv(a, paste0("raw_", o, "_total.pdf"), 6.6, 2.0)
  if (o != "coverage") {
    b <- raw_fig(o, "grid"); if (!is.null(b)) sv(b, paste0("raw_", o, "_grid.pdf"), 6.6, 3.0)
  }
}

# ---------------- event studies --------------------------------------------
es <- fread("results/components_event_study.csv")
ov <- fread("results/components_overall.csv")
M <- function(d) d[basis=="allages" & est=="reg" & sample=="c2014"]
es <- M(es); ov <- M(ov)
es[, `:=`(lo=att-1.96*se, hi=att+1.96*se)]

es_fig <- function(outc, which = c("total","grid")) {
  which <- match.arg(which)
  d <- es[outcome==outc & event_time %between% c(-4,4)]
  d <- if (which == "total") d[toc == "Total"] else d[toc != "Total"]
  if (!nrow(d)) return(NULL)
  LB <- if (which == "grid") slab else tlab
  d[, `:=`(pf=factor(plab[payer], levels=plab), tf=factor(LB[toc], levels=LB))]
  g <- ggplot(d, aes(event_time, att, colour=payer, fill=payer)) +
    geom_hline(yintercept=0, colour=WGRAY, linewidth=0.28) +
    geom_vline(xintercept=-0.5, colour=WGRAY, linetype="dashed", linewidth=0.28) +
    geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.16, colour=NA) +
    geom_line(linewidth=0.55) + geom_point(size=0.7) +
    scale_colour_manual(values=pcol) + scale_fill_manual(values=pcol) +
    scale_x_continuous(breaks=if (which == "grid") c(-2, 2) else c(-4,-2,0,2,4)) +
    scale_y_continuous(n.breaks=3) +
    labs(x="Years relative to expansion", y=paste0("ATT, ", olab[outc]))
  if (which == "total") g + facet_wrap(~pf, nrow=1, scales="free_y") + base(10)
  else g + facet_grid(tf~pf, scales="free_y") + base(9) +
       scale_y_continuous(n.breaks=3) + labs(y=NULL) +
       theme(strip.text.y = element_text(angle = 0, hjust = 0))
}
for (o in names(olab)) {
  a <- es_fig(o, "total"); if (!is.null(a)) sv(a, paste0("es_", o, "_total.pdf"), 6.6, 2.0)
  if (o != "coverage") {
    b <- es_fig(o, "grid"); if (!is.null(b)) sv(b, paste0("es_", o, "_grid.pdf"), 6.6, 3.0)
  }
}

# ---------------- all-payer headline ---------------------------------------
d <- es[outcome=="spend_per_capita" & payer %chin% c("all","mdcd","mdcr","priv","oop") &
        toc=="Total" & event_time %between% c(-4,4)]
d[, pf := factor(plab[payer], levels=plab)]
sv(ggplot(d, aes(event_time, att, colour=payer, fill=payer)) +
   geom_hline(yintercept=0, colour=WGRAY, linewidth=0.3) +
   geom_vline(xintercept=-0.5, colour=WGRAY, linetype="dashed", linewidth=0.3) +
   geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.16, colour=NA) +
   geom_line(linewidth=0.7) + geom_point(size=1) +
   facet_wrap(~pf, nrow=1, scales="free_y") +
   scale_colour_manual(values=pcol) + scale_fill_manual(values=pcol) +
   scale_x_continuous(breaks=c(-4,-2,0,2,4)) +
   labs(x="Years relative to expansion", y="ATT, $ per capita") + base(9),
   "allpayer.pdf", 6.6, 2.2)

# ---------------- relative effect sizes ------------------------------------
pre <- p[grp=="2014 expanders" & year_id <= 2013,
         .(spend=sum(spend,na.rm=TRUE), vol=sum(vol,na.rm=TRUE),
           bene=sum(bene,na.rm=TRUE), pop=sum(pop_ref)), by=.(payer, toc)]
pre[, `:=`(spend_per_capita=spend/pop, spend_per_bene=fifelse(bene>0,spend/bene,NA_real_),
           vol_per_capita=fifelse(vol>0,vol/pop*1000,NA_real_),
           vol_per_bene=fifelse(vol>0&bene>0,vol/bene*1000,NA_real_),
           spend_per_vol=fifelse(vol>0,spend/vol,NA_real_),
           coverage=fifelse(bene>0,100*bene/pop,NA_real_))]
prel <- melt(pre, id.vars=c("payer","toc"), measure.vars=names(olab),
             variable.name="outcome", value.name="base_level")
rel <- merge(ov, prel, by=c("payer","toc","outcome"))
rel[, `:=`(pct = 100*overall_att/base_level,
           lo  = 100*(overall_att-1.96*overall_se)/base_level,
           hi  = 100*(overall_att+1.96*overall_se)/base_level)]
rel <- rel[is.finite(pct) & abs(pct) < 200]
rel[, `:=`(pf=factor(plab[payer], levels=plab),
           tf=factor(tlab[toc], levels=rev(tlab)),
           of=factor(olab[outcome], levels=olab),
           rf=factor(rlab[outcome], levels=rlab))]
# All care only: the full payer x setting x outcome grid is unreadable at slide size.
sv(ggplot(rel[toc=="Total"], aes(pct, pf, colour=payer)) +
   geom_vline(xintercept=0, colour=WGRAY, linewidth=0.3) +
   geom_errorbar(aes(xmin=lo, xmax=hi), orientation="y", width=0, linewidth=0.7) +
   geom_point(size=1.8) +
   facet_wrap(~rf, nrow=1, scales="free_x") +
   scale_colour_manual(values=pcol) + scale_x_continuous(n.breaks=3) +
   labs(x="Effect as % of pre-expansion level (95% CI)", y=NULL) + base(9),
   "relative.pdf", 6.6, 2.1)

# Per-capita spending only, every setting.
sv(ggplot(rel[outcome=="spend_per_capita"], aes(pct, tf, colour=payer)) +
   geom_vline(xintercept=0, colour=WGRAY, linewidth=0.3) +
   geom_errorbar(aes(xmin=lo, xmax=hi), orientation="y", width=0, linewidth=0.7) +
   geom_point(size=1.8) +
   facet_wrap(~pf, nrow=1, scales="free_x") +
   scale_colour_manual(values=pcol) + scale_x_continuous(n.breaks=4) +
   labs(x="Per-capita spending effect as % of pre-expansion level (95% CI)", y=NULL) + base(9),
   "relative_spc.pdf", 6.6, 2.3)

# ---------------- significance and pre-test maps ---------------------------
ov[, `:=`(t = overall_att/overall_se,
          pf=factor(plab[payer], levels=plab),
          tf=factor(tlab[toc], levels=rev(tlab)),
          of=factor(olab[outcome], levels=olab))]
ov[, sig := fcase(abs(t)>2.58, "p<0.01", abs(t)>1.96, "p<0.05",
                  abs(t)>1.64, "p<0.10", default="n.s.")]
ov[, sig := factor(sig, levels=c("p<0.01","p<0.05","p<0.10","n.s."))]
ov[, dir := fifelse(t>0, "up", "down")]
sv(ggplot(ov[!is.na(t)], aes(of, tf)) +
   geom_tile(aes(fill=sig, alpha=dir), colour=BG, linewidth=0.7) +
   facet_wrap(~pf, nrow=1) +
   scale_fill_manual(values=c(`p<0.01`=NAVY, `p<0.05`=TEAL, `p<0.10`=GOLD, `n.s.`=LGRAY)) +
   scale_alpha_manual(values=c(up=1, down=0.45)) +
   labs(x=NULL, y=NULL) + base(7) +
   theme(axis.text.x=element_text(angle=40, hjust=1), panel.grid=element_blank(),
         legend.position="bottom", legend.title=element_blank(),
         legend.text=element_text(size=rel(0.9))),
   "sigmap.pdf", 6.6, 3.0)

ov[, ptr := fcase(pre_p>=0.10, "p>=0.10", pre_p>=0.05, "0.05-0.10", default="fails")]
ov[, ptr := factor(ptr, levels=c("p>=0.10","0.05-0.10","fails"))]
sv(ggplot(ov[!is.na(pre_p)], aes(of, tf)) +
   geom_tile(aes(fill=ptr), colour=BG, linewidth=0.7) +
   facet_wrap(~pf, nrow=1) +
   scale_fill_manual(values=c(`p>=0.10`=TEAL, `0.05-0.10`=GOLD, fails=RED)) +
   labs(x=NULL, y=NULL) + base(7) +
   theme(axis.text.x=element_text(angle=40, hjust=1), panel.grid=element_blank(),
         legend.position="bottom", legend.title=element_blank()),
   "pretestmap.pdf", 6.6, 3.0)

# ---------------- tables ----------------------------------------------------
fmt <- function(a,s){t<-abs(a/s)
  st<-fifelse(t>2.58,"***",fifelse(t>1.96,"**",fifelse(t>1.64,"*","")));st[is.na(st)]<-""
  sprintf("%s%s", formatC(a,format="f",digits=1,big.mark=","), st)}
mktab <- function(outc, file) {
  t <- ov[outcome==outc & !is.na(overall_att)]
  t[, cell := paste0(fmt(overall_att, overall_se), " (", formatC(overall_se,format="f",digits=1,big.mark=","), ")")]
  w <- dcast(t, payer ~ toc, value.var="cell")
  w <- w[match(names(plab), payer)][!is.na(payer)]
  L <- c("\\begin{tabular}{@{}l rrrrrr@{}}","\\toprule",
         paste0("Payer & ", paste(tlab, collapse=" & "), " \\\\"),"\\midrule")
  for (i in seq_len(nrow(w))) { r <- w[i]
    v <- sapply(names(tlab), function(k){z<-r[[k]]; if(is.null(z)||is.na(z)) "---" else z})
    L <- c(L, sprintf("%s & %s \\\\", plab[r$payer], paste(v, collapse=" & "))) }
  writeLines(c(L,"\\bottomrule","\\end{tabular}"), file.path(TAB, file))
}
for (o in names(olab)) mktab(o, paste0("tab_sv_", o, ".tex"))

message("survey assets written")
