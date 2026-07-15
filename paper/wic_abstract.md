# WIC Abstract Draft

**Title:** Who pays after Medicaid expansion? Cross-payer effects on healthcare spending and utilization in US states, 2010–2019

**Background:** Medicaid expansion under the Affordable Care Act increased coverage and access for low-income adults, and prior work documents utilization gains among the newly eligible. Less is known about how expansion affected the full payer mix: whether new Medicaid spending displaced out-of-pocket and private spending, and whether spillovers reached Medicare. We estimate the effect of Medicaid expansion on healthcare spending and utilization by payer and type of care.

**Methods:** We use state-level, age/sex-standardized estimates of healthcare spending and utilization from the Institute for Health Metrics and Evaluation's Disease Expenditure project (DEX 2.0), covering ambulatory, emergency department, inpatient, nursing facility, and pharmacy care for Medicaid, Medicare, private insurance, and out-of-pocket payment from 2010 to 2019. We estimate group-time average treatment effects using the Callaway and Sant'Anna estimator to account for staggered expansion between 2014 and 2018, with not-yet-expanded states as controls and doubly robust adjustment for state income, poverty, age structure, and pre-expansion uninsurance. Estimates are consistent across inverse probability weighting, regression, and Sun and Abraham specifications, and when restricting to 2014 expanders.

**Preliminary results:** Expansion increased Medicaid spending per capita in ambulatory, inpatient, and emergency department care, while Medicaid spending per beneficiary was unchanged, consistent with enrollment growth rather than higher intensity of care per enrollee. Out-of-pocket spending per capita declined in the same settings. We find no evidence of changes in Medicare spending or utilization. Estimates for private insurance are imprecise but suggest higher per-beneficiary ambulatory spending, which may reflect compositional change as lower-cost enrollees moved to Medicaid.

**Conclusions:** Preliminary estimates suggest Medicaid expansion shifted the financing of care from households to Medicaid without measurable spillovers to Medicare. Final results will quantify these effects and their heterogeneity across care settings and expansion cohorts.

---

## Notes (not part of the abstract)

- ~300 words (excluding title). The WIC submission form is an Excel download; check it for the actual word cap and required fields before submitting.
- Exact dollar estimates are intentionally omitted: `results/overall_att_SA_results.csv` holds the Sun-Abraham sensitivity run, not the main Callaway–Sant'Anna estimates. If the form wants numbers, pull headline ATTs from the CS model first.
- Treated-cohort window is stated as 2014–2018 per `methods_notes.qmd`; `paper.qmd` says 2014–2017. Reconcile before submission.
- Voice is "we" (matching `paper.qmd` co-author placeholder); switch to "I" if submitting solo.
- Fits WIC theme 2: causal inference from observational data.
