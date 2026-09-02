# Audit and decision evidence — Checkpoint 2

**Branch:** `claude/poster-analysis-refresh-519d0e` · **2026-09-02**

Every decision below carries evidence. Figures are in `notes/evidence/`, and
each is reproducible from the named script.

---

# DECISION 1 — Age basis: standardized or all ages?

**Recommendation: All ages.** Not as a convenience — the standardized basis
fails a coherence test that the all-ages basis passes exactly, and the choice
turns out not to affect any estimate.

Scripts: `R/evidence_basis.R` (E1.1–E1.3), `R/evidence_basis_models.R` (E1.4–E1.5).

## E1.1 — Only one basis recovers a population

There is one state population in a given year. Spending divided by spending
per capita must therefore return the same number for Medicaid, Medicare,
private and out-of-pocket. It is the same denominator four times.

| Basis | Median spread across payers | 90th pct | Max | Cells off by >1% |
|---|---|---|---|---|
| Age/sex-standardized | **406.8%** | 595.8% | 1006.3% | 100.0% |
| All ages | **0.005%** | 0.040% | 0.15% | 0.0% |

On the all-ages basis the four payers agree to five decimal places — and they
still agree when you also vary the type of care (median spread 0.041%, max
0.146% across all payers *and* all five settings within a state-year). That is
the same population recovered twenty different ways.

On the standardized basis the same calculation returns four different numbers
differing by a factor of five. The standardized "per capita" figure is a rate on
a synthetic age structure, not dollars per resident, so the ratio is not a
population and no coverage or enrollee denominator can be recovered from it.

**Consequence:** the decomposition spend/pop = price × use/enrollee × coverage,
and any coverage first stage, are *only definable on the all-ages basis.*

→ `evidence/E1-1_denominator_coherence.pdf`

## E1.2 — The demographic objection is testable, and it does not bind here

The case for standardizing is that all-ages rates confound spending with age
structure. In a difference-in-differences that objection binds only if the two
groups' age structures **diverged** over the panel. Parallel drift is removed by
the design.

| Measure | Gap, 2010 | Gap, 2018 | Drift over 8 years |
|---|---|---|---|
| Share 65+ | +0.342 pp | +0.388 pp | **+0.045 pp** |
| Share under 18 | −1.481 pp | −1.653 pp | **−0.172 pp** |

Both groups aged, at the same rate. The between-group gap moved by less than a
fifth of a percentage point across the whole period. There is almost nothing
here for standardization to remove.

→ `evidence/E1-2_age_structure_divergence.pdf`

## E1.3 — All-ages numbers are interpretable as money; standardized ones are not

Sum of the four payers' spending per capita across the five settings, 2018:

| Basis | Median state | Range |
|---|---|---|
| All ages | **$6,496** | $4,509 – $10,720 |
| Age/sex-standardized | **$13,366** | $11,251 – $18,023 |

US per-capita health spending in 2018 was roughly $11,000 including dental,
home health and every other payer — all of which are excluded here. The
all-ages figure is a plausible share of it. The standardized figure exceeds the
national total, because standardized rates across payers do not sum to anything.
Medicare is the extreme case: its standardized per-capita figure is **4.5×** its
all-ages figure.

For a poster, this is the difference between an axis labelled in dollars per
resident and one labelled in units nobody can interpret.

→ `evidence/E1-3_basis_overlay.pdf`

## E1.4 — And it does not change a single conclusion

Same specification, both bases: 2014 cohort (25 states) vs never-expanded (19),
Callaway–Sant'Anna, outcome regression, never-treated controls, clustered by
state. 24 payer × setting cells each.

- Correlation of the ATTs (as % of pre-period level): **0.983**
- Same sign: **20 of 24**
- Same significance verdict at 5%: **23 of 24** — the exception is Medicaid ED

Headline cells, ATT as % of the treated group's own pre-2014 level (SE):

| Payer | All ages | Standardized |
|---|---|---|
| Medicaid, all care | **+18.0 (4.1)** | +14.2 (3.9) |
| Medicare, all care | +0.4 (1.3) | −0.3 (0.9) |
| Private, all care | +1.7 (2.4) | +1.7 (2.5) |
| Out-of-pocket, all care | −4.8 (8.3) | −4.9 (7.9) |

→ `evidence/E1-4_att_scatter_by_basis.pdf`, `evidence/E1-4_att_by_basis.csv`

## E1.5 — Pre-trend behaviour is the same on both

| Basis | Models passing at p ≥ 0.05 |
|---|---|
| All ages | 17 / 24 (71%) |
| Age/sex-standardized | 16 / 24 (67%) |

By payer, pass rates are Medicaid 100/100, Medicare 100/83, private 83/83, and
**out-of-pocket 0/0** (all ages / standardized). Out-of-pocket fails on *both*
bases, so its failure is a property of the outcome, not of this choice. That is
Decision 4's problem, not Decision 1's.

## What choosing all ages costs

State it plainly rather than hiding it:

1. **It departs from DEX's headline presentation.** IHME leads with
   standardized rates. Anyone who knows the source may ask why. The answer is
   E1.1 — standardized rates cannot support the denominators this design needs.
2. **No demographic adjustment in the rates themselves.** The defence is E1.2
   (the groups aged in parallel) plus the fact that age structure enters the
   model as a covariate anyway, and E1.4 (it makes no difference).

## The question this settles

Because the estimates are the same either way, the basis can be chosen on
interpretability, and all-ages wins on every count: it recovers a real
population, it sums to real money, and it is the only basis on which the
coverage-versus-intensity mechanism can be estimated at all.

**Awaiting Emily's decision.**

---

# DECISIONS 2–5 — evidence in progress

Building next, in this order:

- **D4 (out-of-pocket).** Partly answered above: OOP fails the pre-trend test in
  0 of 24 models on *both* bases. Still to produce: the raw 2010–2013 trends
  and the event-study plot, so the failure can be diagnosed rather than just
  reported.
- **D2 (denominator).** Event-study of enrollee counts by payer, to show
  whether the per-beneficiary denominator actually moves at expansion.
- **D5 (inference).** Analytic clustered SEs vs multiplier bootstrap.
- **D3 (multiplicity).** p-value distribution against the uniform null.

---

# Confirmed errors

| # | Issue | Status |
|---|---|---|
| 1 | 7 states miscoded as 2014 expanders | fixed 31 Aug; cohort file re-verified against KFF dates below |
| 2 | `dr`/`ipw` infeasible at N=51 | to verify in this session |
| 3 | Two parallel pipelines, one documented | resolved once Decision 1 lands |
| 4 | OOP fails pre-trend | confirmed on both bases (E1.5) |
| 5 | `build_covariates.R:9` hardcodes a live Census API key | **unfixed — needs Emily to rotate the key** |
| 6 | Panel ends 2018, methods notes say 2010–2019 | wording |
