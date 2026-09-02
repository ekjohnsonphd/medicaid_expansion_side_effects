# Candidate material for the poster

**2026-09-02.** Twelve figures and two tables. Nothing here is a layout
proposal — these are the pieces to choose from. `catalogue.pdf` has all twelve
figures in the order below; individual PDFs are alongside it.

Built by `R/figures_candidates.R` from `R/prep_panel.R` and
`results/toc_effects.csv`.

---

## First: which visual idiom?

Three ways to draw the same DiD, and they are not equivalent.

| | Candidate | What it plots | Problem |
|---|---|---|---|
| **Levels** | C2 | Both groups' actual dollars | Groups start at different levels, so the eye reads the baseline gap, not the effect |
| **Indexed** | C3, C3b | Each group indexed to its own 2013 | **Changes the estimand.** Indexing shows *ratio* growth; the estimator reports a *level* difference as a share of the treated baseline. Where baselines differ these disagree — for private they disagree in sign |
| **Counterfactual** | **C9, C10, C11** | Treated actual vs the control group's change applied to the treated group's own 2013 level | The vertical gap *is* the difference-in-differences, in dollars, and pre-trend parallelism shows as the two lines overlapping |

**The indexing problem, concretely.** Private spending per resident: treated
$2,577 → $2,892 (+12.2%), control $2,287 → $2,609 (+14.1%). Indexed, that reads
as a 1.9-point gap favouring the controls. The level difference-in-differences
is **−0.3%**, and the estimate in the table is +1.7% (SE 2.5). The indexed
picture would contradict your own table on the poster.

**Recommendation: the counterfactual idiom.** It answers both of your
objections to forest plots — pre-trends are visible as overlapping lines, the
level pattern over time is visible, and the gap is in dollars rather than
abstracted into a percentage.

---

## The figures

| # | Figure | Serves | Notes |
|---|---|---|---|
| **C1** | Coverage: Medicaid, private, uninsured, Medicare, both groups | **Point 1** | The obvious one. Four panels, two lines each, levels in percentage points — no indexing problem because coverage is already a share |
| **C9** | Medicaid actual vs counterfactual, per resident and per enrollee | **Point 2** | The flagship. Left panel: lines overlap to 2013 then split hard. Right panel: they track. That contrast *is* the finding |
| **C10** | All four payers, per resident, vs counterfactual | Points 2 and 4 | Medicaid separates, Medicare and private sit on their counterfactuals, out-of-pocket visibly wanders before expansion |
| **C11** | Private actual vs counterfactual, both margins | **Point 3** | Per resident sits on the counterfactual; per enrollee a small gap opens |
| C2 | Medicaid, levels, both groups | Point 2 | The honest levels version. Baseline gap dominates the right panel |
| C3 | Medicaid, indexed to 2013 | Point 2 | Legible, but see the estimand problem above |
| C3b | C3 on one shared y-axis | Point 2 | Shows how much smaller the per-enrollee movement is. A free scale makes a flat series look noisy |
| C4 | Medicaid per resident by setting, six panels | Point 2 detail | Significant in ambulatory, ED, inpatient; flat in nursing and pharmacy |
| C5 | Private, indexed, both margins | Point 3 | Superseded by C11 |
| C6 | Private: encounters per enrollee against spending per enrollee | **Point 3** | The use-not-price evidence. Encounters move +3.3% against spending +4.8% |
| C7 | Medicare and out-of-pocket, indexed | Point 4 | Out-of-pocket's crossing pre-period lines are the clearest statement of why it is not interpreted |
| C8 | All four payers, indexed | Points 2 and 4 | Superseded by C10 |

## The tables


### T1. Coverage

| Measure | Effect (pp) | SE | p | Pre-trend p | Source |
| ---|---|---|---|---|--- |
| Medicaid | +3.69 | 0.78 | 0.000 | 0.84 | DEX |
| Medicare | -0.20 | 0.17 | 0.258 | 0.72 | DEX |
| Uninsured | -1.38 | 0.55 | 0.013 | 0.30 | CPS |
| Private | -2.16 | 0.45 | 0.000 | 0.96 | DEX |

### T2. All care, every payer and margin (% of pre-2014 level)

| Payer | $/resident | $/enrollee | Enc/resident | Enc/enrollee | Pre-trend p |
| ---|---|---|---|---|--- |
| Medicaid | +18.0 (4.0)* | -3.3 (4.2) | +10.1 (5.9) | -15.4 (6.9)* | 0.42 |
| Medicare | +0.4 (1.3) | +1.5 (0.9) | -0.5 (1.7) | +1.1 (1.1) | 0.79 |
| Out-of-pocket | -4.8 (7.9) | -- | -6.4 (11.5) | -- | 0.00 |
| Private | +1.7 (2.5) | +4.8 (3.0) | +0.3 (2.4) | +3.3 (2.4) | 0.07 |

**Caveat on T2.** The starred −15.4% for Medicaid encounters per enrollee is an
aggregation artefact and should not be shown as a finding: total volume sums
prescription fills with hospital stays, prescriptions dominate the count
923-to-51, and no individual setting is significant. Either drop the
Enc/enrollee column, or split it by setting.

**Caveat on out-of-pocket.** Its pre-trend p is 0.00 to two decimals. If it
appears in a table at all, the row should be visibly marked as not identified.

**Not yet built, and cheap if wanted:** a by-setting table (all 84 estimates),
an event-study panel, and the counterfactual idiom applied by setting.

---

## What still needs deciding

- **The idiom** — counterfactual, levels, or indexed.
- **Decision 3**, still tabled. The guard depends on how many estimates the
  poster shows. C1 + C9 + C11 puts roughly a dozen numbers on the wall; the
  full by-setting tables put up 84.
- **The template** — yours to give.

---

# Second pass: uncertainty, and the whole information set

Added 2026-09-02 after Emily's note that none of the first-pass figures showed
variance. `R/figures_full.R`.

## How the uncertainty is drawn

Error bars on group means would show the wrong thing — the spread across states,
not the precision of the estimate. Instead the counterfactual is built **from the
estimator**:

>  counterfactual_t = actual_t − ATT_t,  band = counterfactual_t ∓ 1.96 · SE_t

with ATT_t and SE_t from the Callaway–Sant'Anna event study. Two consequences
worth stating out loud, because they make these figures readable at a glance:

- **Before 2014**, the band is the parallel-trends test drawn in dollars. The
  actual line sitting inside its own band is a passing pre-test.
- **After 2014**, the actual line leaving the band is a significant effect.

So one picture carries the estimate, its precision, and its identifying
assumption. Nothing is abstracted into a percentage.

| # | Figure | Serves | Notes |
|---|---|---|---|
| **C14** | Medicaid, both margins, with band | **Point 2** | Left: inside the band to 2013, then clean break above it. Right: inside the band throughout. The contrast is the finding |
| **C15** | All four payers, per resident, with band | Points 2 and 4 | Only Medicaid leaves its band. Out-of-pocket leaves it *before* 2014, which is the pre-trend failure made visible |
| **C16** | Private, three margins, with band | **Point 3** | Spending per resident, spending per enrollee, encounters per enrollee. The actual path stays inside every band — the honest version of "weak evidence" |
| **C17** | **Every payer × every setting, per resident, with bands** | the whole set | 20 panels, each on its own scale. Medicaid ambulatory, emergency and inpatient break out; nothing else does. This is the information set behind every headline number |

**On C17 and per-panel scales.** The first build used `facet_grid`, which shares
one y-axis across each row and crushed panels whose levels differ — Medicaid
ambulatory at $450 against private at $1,400. It now uses `facet_wrap` so each
panel is scaled to its own series. Worth knowing if a version of this reaches
the poster: shared scales would misrepresent the small-level payers.

## Revised recommendation

C1 for point 1, **C14** for point 2, **C16** for point 3, **C15** for point 4,
and **C17** as the backing detail — on the poster if there is room, in your hand
at the board if not. C9–C11 remain available as the no-uncertainty versions if
the banded ones read as too busy at A0.
