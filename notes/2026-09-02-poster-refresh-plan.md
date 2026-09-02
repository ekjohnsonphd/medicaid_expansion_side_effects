# Plan of attack — WIC poster, 9 September 2026

**Written:** 2026-09-02 · **Branch:** `claude/poster-analysis-refresh-519d0e`
**Budget:** one working day. **Deliverable:** an A0 poster Emily can present and defend.

Emily edits this file. Anything marked **[DECISION]** is hers to make and I will
not proceed past the checkpoint that contains it without an answer.

---

## Agreed at the outset

1. **Conceptual reset to February scope.** One question, one design, one
   documented pipeline. The genuine corrections from the 31 Aug sprint are kept
   (cohort coding, reg-not-dr, the small-cohort placebo diagnostic). The sprawl
   is discarded.
2. **The existing poster and decks are scrapped.** Emily was not involved in
   producing them, so they cannot be presented. Git history retains them.
3. **Everything on the new poster is re-estimated in this session** from a
   pipeline Emily has read.
4. **The poster's central claim is chosen at Checkpoint 3**, after we both trust
   the numbers — not before.

## The standard this has to meet

Emily presents this alone and takes questions. So:

- The final pipeline is **one script, readable start to finish in one sitting**.
  If it needs more than that, the scope is wrong.
- Every number on the poster traces to a named line of that script.
- Each checkpoint delivers a **short written memo**, not a code dump.
- The last deliverable is a **defence sheet**: the questions a WIC audience will
  actually ask, with answers grounded in what we ran.

---

## Stage 0 — Reset the workspace  *(~20 min, no checkpoint)*

- Symlink `data/dex` into the worktree (source file is gitignored and lives only
  in the main checkout, so nothing here currently runs).
- Delete on this branch: `poster/`, `slides/`, `results/*.csv`,
  `figures/fig_event_study.R`, `spending_did_results.html`.
- Delete superseded scripts: `expansion_did.R`, `expansion_eventstudy.R`,
  `expansion_components.R`, `data.R` (empty).
- **Leave alone:** `app.R` + `deploy.R` (Shiny app, separate artefact),
  `build_covariates.R`, `data/`, `paper/`, `R/`.
- Commit the deletion as its own commit so the reset is legible in the log.

**[DECISION 0]** Confirm the delete list. Anything on it you want kept?
CONFIRMED. NO NEED FOR MY VERIFICATION.

## Stage 1 — Audit and design memo → **CHECKPOINT 2**  *(~60 min mine, ~20 min yours)*

I read every surviving analysis file and write `notes/audit.md` containing:

**(a) Confirmed errors** — with evidence, not assertion. Already known:

| # | Issue | Status |
|---|---|---|
| 1 | 7 states (ID, UT, NE, MO, OK, SD, NC) miscoded as 2014 expanders | fixed 31 Aug, verify |
| 2 | `dr`/`ipw` infeasible at N=51 — perfect separation, cells return NA | confirmed, spec is `reg` |
| 3 | Methods notes document the standardized pipeline; the scrapped poster showed the all-ages one | unresolved |
| 4 | Every OOP spend-per-capita model fails the pre-trend test | acknowledged but under-weighted |
| 5 | `build_covariates.R:9` hardcodes a live Census API key | unfixed |
| 6 | Panel ends 2018; abstract says 2010–2019 | wording |

**(b) Load-bearing choices needing your call.** These look like details and are not:

- **[DECISION 1] Age basis.** Standardized removes demographic composition from
  the rates, which is the defensible choice for a spending comparison. But under
  standardization the implied population is not a population, so you cannot
  recover enrollee or population denominators — which kills both the coverage
  first stage and the three-way decomposition. All-ages keeps them and gives up
  the adjustment. *You cannot have both.* My read: this choice determines
  whether the poster can tell a mechanism story at all. 
- **[DECISION 2] Denominator.** Spend **per capita** has a fixed denominator and
  is the policy-relevant quantity. Spend **per beneficiary** has an
  *endogenous* denominator — expansion changes who is enrolled, so a
  per-enrollee effect confounds price/intensity with composition. The scrapped
  poster's "private per enrollee rises" claim is exactly this problem. I
  recommend per capita as primary, per beneficiary only as an explicitly
  labelled compositional diagnostic.
- **[DECISION 3] Multiplicity.** We will estimate on the order of 40–100
  models. Options: pre-register a small primary set and label the rest
  exploratory; report q-values; or report nothing beyond the primary set.
- **[DECISION 4] What to do about OOP** given the pre-trend failure. Drop it,
  report it as not identified, or keep it with the failure stated on the poster.
- **[DECISION 5] Clustering and inference.** Currently clustered by state with
  wild-bootstrap not used. With 19 control states, cluster-robust SEs are on the
  edge of where bootstrap is usually recommended.

**(c) Proposed expansions** — I will argue for or against each, you choose:
honest-DiD / Rambachan–Roth sensitivity for the pre-trend concern; a
never-treated-only control definition stated explicitly; the 1115-waiver
exclusion; and whether the staggered sample returns as a robustness panel.

**You review the memo and answer DECISIONS 1–5.** This is the gate.
EJ: I WILL NEED A LIST OF PIECES OF EVIDENCE FOR EACH DECISION THAT YOU CAN PROVIDE. A DESCRIPTION OF THE CHOICE IS INSUFFICIENT. I WOULD PREFER TO BE ABLE TO SEE PREVIOUS RESULTS VISUALLY.

## Stage 2 — Re-estimate  *(~90 min including runtime)*

One script, `R/estimate.R`, written to the decisions from Checkpoint 2. Scope
proposal (edit freely):

- **Primary:** 4 payers × {Total + 5 settings}, spend per capita, 2014 cohort vs
  19 never-expanders, `reg` with the agreed covariates. ~24 models.
- **First stage:** coverage share by payer (only if DECISION 1 permits).
- **Sensitivity, named in advance:** `dr` on the reduced covariate set;
  waiver-restricted states excluded; full staggered sample.
- Writes **one** tidy CSV plus an event-study CSV. No 1332-model matrix.

Output to you: the numbers, in a table, with a paragraph on what changed
relative to the pre-correction results and why.

## Stage 3 — Results review → **CHECKPOINT 3**  *(~30 min yours)*

You see the estimates and decide:

- **[DECISION 6]** The poster's central claim — the null-with-bounds framing,
  the decomposition/mechanism framing, or an explicit reconciliation with the
  submitted abstract.
- **[DECISION 7]** How to handle the abstract conflict. Your submitted abstract
  promises OOP falls and private per-enrollee rises. The corrected analysis may
  not support either. Someone in the room may have read it. THIS DOESN'T MATTER. IT IS TO BE EXPECTED THAT ANALYSIS CHANGES OVER TIME SINCE AN ABSTRACT SUBMISSION. REMOVE.
- **[DECISION 8]** You give me the poster template: layout, panel count,
  house/institutional style, fonts, colours, size, and any WIC formatting rules.

## Stage 4 — Figures and tables → **CHECKPOINT 4**  *(~90 min)*

Each figure and table drafted individually with a one-line rationale for why it
earns its space. Rendered to PDF and sent to you before any poster assembly.
You cut and reorder. Nothing goes on the poster that you have not seen alone.

## Stage 5 — Build the poster → **CHECKPOINT 5**  *(~90 min)*

Assemble to your template, render, send you the PDF, revise on your formatting
and look notes. Then:

- Rewrite the one-minute pitch to match the *new* analysis.
- Write the **defence sheet** — anticipated questions and grounded answers.
- Final commit and push.

---

## Rough clock

| | Stage | Mine | Yours |
|---|---|---|---|
| | 0 Reset | 20m | 5m |
| **CP2** | 1 Audit + design memo | 60m | 20m |
| | 2 Re-estimate | 90m | — |
| **CP3** | 3 Results review + template | 15m | 30m |
| **CP4** | 4 Figures and tables | 90m | 20m |
| **CP5** | 5 Poster build + defence sheet | 90m | 30m |
| | **Total** | **~6h** | **~1h50m** |

Slack is thin. If we fall behind, the first thing cut is the sensitivity suite
in Stage 2, not a checkpoint.

## Risks

1. **The corrected result may be a null**, and a null poster is harder to
   present than the abstract implied. Decided at Checkpoint 3, not assumed here.
2. **DECISION 1 is a genuine trade-off with no free option.** If it goes to
   standardized, the mechanism story is unavailable and the poster is thinner.
3. **One day.** If Stage 1 uncovers an error deeper than the six listed, we
   re-plan rather than push through — I will say so at Checkpoint 2.
