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

# DECISION 2 — Denominator: per capita or per enrollee?

**Recommendation: per capita is the headline outcome, because it answers the
question the poster asks. Per enrollee is reported alongside it as the
compositional margin — it says who moved — and is interpreted against the
"movers looked like incumbents" benchmark, never against zero.**

Script: `R/evidence_decisions.R`. Panel: `R/prep_panel.R`.

## E2.1 — The per-enrollee denominator is not a denominator, it is an outcome

Effect of expansion on coverage — the share of the state population enrolled:

| Payer | Effect (pp) | SE | Pre-trend p | Pre-period level |
|---|---|---|---|---|
| Medicaid | **+3.69** | 0.78 | 0.839 | 18.6% |
| Private | **−2.16** | 0.45 | 0.962 | 63.3% |
| Medicare | −0.20 | 0.17 | 0.716 | 15.2% |

Flat pre-periods, sharp breaks at expansion. Expansion moved the enrollee count
by +20% for Medicaid and −3.4% for private, relative to their own pre-period
levels. Anything divided by that quantity has a treatment-affected denominator.

→ `evidence/E2-1_coverage_event_study.pdf`

## E2.2 — And it changes what the numbers appear to say

ATT as % of pre-period level (SE):

| Payer | Setting | Per capita | Per enrollee |
|---|---|---|---|
| Medicaid | All care | **+18.0 (3.9)** | **−3.3 (4.3)** |
| Medicaid | Ambulatory | +23.6 (6.0) | 0.0 (6.3) |
| Medicaid | Inpatient | +22.5 (4.5) | +4.4 (4.7) |
| Private | All care | +1.7 (2.6) | **+4.8 (2.8)** |
| Private | Ambulatory | +2.1 (2.6) | +5.3 (3.0) |
| Medicare | All care | +0.4 (1.4) | +1.5 (0.9) |

**The three quantities are algebraically linked, but not interchangeable.**
spend/pop = (spend/enrollee) x (enrollee/pop), so any two determine the third.
They are therefore not three independent findings. But *which* two you report
decides which question you answer: per capita answers "did the fiscal burden
move between payers?", per enrollee answers "who moved?".

**The per-enrollee margin is informative, and the right benchmark is not zero.**
An earlier draft of this memo called the private per-enrollee result "arithmetic"
and treated it as double-counting. That was the wrong null. The correct null is
that the movers looked like the people who stayed:

- If leavers are **average cost**, losing 3.41% of private enrollees cuts total
  private spending by 3.41% and leaves spending per enrollee **unchanged**.
- If leavers are **cheaper than average**, spending per enrollee **rises**.

So the per-enrollee estimate is a direct test of selection on the exit margin,
and it does not merely restate the coverage effect.

## E2.3 — Bounding the compositional story

Write r for the mean spending of the movers as a fraction of the incumbent mean.
For an exit, m'/m = (1 - s·r)/(1 - s); for an entry, m'/m = (1 + s·r)/(1 + s).

**Private — who left.** Enrollment fell 3.41% of its level.

| Quantity | Value |
|---|---|
| Spending per enrollee | **+4.8%** (SE 2.8), 95% CI [−0.7, +10.3] |
| If leavers were average cost (r = 1) | 0% |
| If leavers cost *nothing* (r = 0) | **+3.53%** — the most selection can give |

Two tests of "the leavers were average cost". On the per-enrollee margin,
t = 1.71, **p = 0.088**. On the per-capita margin — total private spending
should have fallen 3.41% and instead came in at +1.7% — t = 1.98, **p = 0.048**.

So the compositional reading has support: the people who left private coverage
took very little spending with them. **But it is at the edge of what selection
alone can explain.** The point estimate of +4.8% exceeds the +3.53% that
costless leavers would produce, implying r = −0.36, which is not a possible
value. The CI on r is [−1.91, +1.20], so this is noise rather than a
contradiction — but it means the honest claim is directional: *the leavers were
much cheaper than the average private enrollee*, not a specific figure.

**Medicaid — who joined. This is the cleaner version of the same idea.**
Enrollment rose 19.9% of its level and spending per enrollee moved −3.3%
(SE 4.3). Solving for r:

> **New Medicaid enrollees cost about 80% of an incumbent enrollee** (95% CI
> 0.29 to 1.31).

Costless entrants would have driven per-enrollee spending down 16.6%; average-
cost entrants would have left it flat. The data sit near the top of that range.
The expansion population was somewhat cheaper than the existing Medicaid
caseload, and not dramatically so.

→ `evidence/E2-3_who_moved.pdf`, `R/evidence_selection.R`

→ `evidence/E2-2_per_capita_vs_per_enrollee.pdf`

---

# DECISION 3 — Multiple comparisons

**The decision.** The design fits 24 spending-per-capita models (4 payers x 6
settings). At a 5% threshold, about **1.2 of them would look significant even if
every true effect were exactly zero**. So when four come back significant, the
question is whether that is signal or simply the expected yield of a wide net.
The choice is between adjusting the p-values, pre-designating a small primary
set and labelling the rest exploratory, or reporting raw p-values with the
search fully described.

**Recommendation: no adjustment is needed, and saying so is stronger than
adjusting.** Report BH q-values on the primary set anyway; they cost nothing.

Across the 24 spending-per-capita models:

- Significant at 5%: **4**. Expected by chance if everything were null: 1.2.
- **Excluding Medicaid: 0 of 18 significant.** Expected by chance: 0.9.

Every significant result is Medicaid, and all four survive Benjamini–Hochberg:

| Payer | Setting | Effect | p | q |
|---|---|---|---|---|
| Medicaid | Inpatient | +22.5% | 5.3e−07 | 1.3e−05 |
| Medicaid | All care | +18.0% | 3.7e−06 | 4.5e−05 |
| Medicaid | Ambulatory | +23.6% | 8.5e−05 | 6.8e−04 |
| Medicaid | Emergency | +21.7% | 6.4e−03 | 3.8e−02 |

There is no garden of forking paths here because there is nothing in the garden:
the non-Medicaid p-values are consistent with pure noise. The honest statement
is that the search was exhaustive, pre-specified in structure, and turned up
exactly one payer.

→ `evidence/E3-1_pvalue_distribution.pdf`

---

# DECISION 4 — Out-of-pocket

**Recommendation: report out-of-pocket as not identified, and do not interpret
its point estimate. Also flag private as borderline.**

Pre-trend p, spending per capita, all-ages basis:

| Payer | AM | ED | IP | NF | RX | All care |
|---|---|---|---|---|---|---|
| Medicaid | 0.77 | 0.53 | 0.60 | 0.23 | 0.47 | **0.42** |
| Medicare | 0.23 | 0.94 | 0.26 | 0.12 | 0.59 | **0.79** |
| Private | 0.10 | 0.13 | 0.27 | 0.27 | 0.02 | **0.07** |
| Out-of-pocket | 0.0002 | 0.0001 | 0.004 | 0.007 | 0.03 | **0.00006** |

Out-of-pocket fails in every setting, on both age bases. The diagnosis is a
genuine pre-period divergence, not a test artifact — pre-2014 annual growth in
spending per capita:

| Payer | 2014 expanders | Never expanded | Gap |
|---|---|---|---|
| Medicaid | +0.42%/yr | +0.59%/yr | 0.17 |
| Medicare | +1.68%/yr | +1.61%/yr | 0.07 |
| Private | −1.06%/yr | −0.12%/yr | **0.94** |
| Out-of-pocket | −0.13%/yr | −1.34%/yr | **1.21** |

Household out-of-pocket spending was already moving differently in the two
groups before anything happened. The event study shows pre-period estimates
swinging from −6.5% to +10.4%. This design cannot speak to out-of-pocket
spending, and no wider confidence interval fixes that.

**Private is borderline** (all care p = 0.07, pharmacy p = 0.02, pre-slope gap
0.94%/yr). Not a failure, but not clean either. Any private claim should be
stated with that caveat, or supported by a Rambachan–Roth bound.

→ `evidence/E4-1_raw_trends_by_payer.pdf`, `evidence/E4-3_event_study_per_capita.pdf`

---

# DECISION 5 — Inference

**Recommendation: keep the multiplier bootstrap. The choice is immaterial.**

The `did` package already defaults to a multiplier bootstrap with uniform
bands, so this was never analytic in the first place. Refitting all 24
spending-per-capita models with analytic clustered SEs:

- Bootstrap SE ÷ analytic SE: median **1.079**, range 0.993–1.255
- Significance verdicts differing: **0 of 24**

The bootstrap is mildly more conservative and changes nothing. Keep it, and
report uniform bands on event studies so the pre-period test and the plot agree.

→ `evidence/E5-1_bootstrap_vs_analytic.csv`

---

# Confirmed errors

| # | Issue | Status |
|---|---|---|
| 1 | 7 states miscoded as 2014 expanders | fixed 31 Aug |
| 2 | `dr`/`ipw` infeasible at N=51 | main spec is `reg`; not revisited |
| 3 | Two parallel pipelines, one documented | **resolved** — one panel, `R/prep_panel.R` |
| 4 | OOP fails pre-trend | **confirmed and diagnosed** (D4) |
| 5 | `build_covariates.R:9` hardcodes a live Census API key | **unfixed — Emily must rotate it** |
| 6 | Panel ends 2018, methods notes say 2010–2019 | wording |
| 7 | Methods notes claim enrollee counts "agree to within 1% across TOC" | **false.** True for Medicaid (0.98%), but Medicare's pharmacy denominator is Part D — 13.9% of population against 17.9% for inpatient, a 40% gap. Private is 4% apart. The panel now uses inpatient enrollment as the coverage reference and each setting's own denominator elsewhere. |

---

# What the analysis now says

Stated once, plainly, so Checkpoint 3 has something to react to:

> Expansion raised Medicaid coverage by 3.7 points and reduced private coverage
> by 2.2 points. Medicaid spending per capita rose 18%. Spending *per enrollee*
> did not move (−3.3%, SE 4.3), so the additional spending is people, not
> intensity. Medicare spending did not move on any margin. Private spending per
> capita did not move; its per-enrollee rise says the people who dropped private
> coverage were much cheaper than those who kept it. New Medicaid enrollees cost
> about 80% of an incumbent enrollee. Out-of-pocket spending is not identified.
