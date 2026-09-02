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

## Stage 1 — Audit and evidence run → **CHECKPOINT 2**  *(~2h mine, ~30m yours)*

**Revised on Emily's note:** a description of each choice is insufficient. Every
decision below ships with named evidence, visual where a figure beats a
sentence. For the age basis this means **estimating on both bases before the
decision**, not after, and handing over the comparison.

Output: `notes/audit.md` plus a figure pack in `notes/evidence/`.

### (a) Confirmed errors — verified, not asserted

| # | Issue | Evidence I produce |
|---|---|---|
| 1 | 7 states miscoded as 2014 expanders | cohort file re-checked against KFF implementation dates, printed table |
| 2 | `dr`/`ipw` infeasible at N=51 | propensity-score fit shown separating; count of NA (g,t) cells by covariate count |
| 3 | Two parallel pipelines, one documented | resolved by Decision 1 — one basis survives |
| 4 | OOP fails the pre-trend test | see Decision 4 evidence |
| 5 | `build_covariates.R:9` hardcoded Census API key | fixed in Stage 0 follow-up; key must be rotated by Emily |
| 6 | Panel ends 2018 | wording fix in methods notes |

### (b) Decisions, each with its evidence

**[DECISION 1] Age basis — standardized vs all ages.** Emily leans all-ages;
this is the evidence that would justify or block it.

- **E1.1 Denominator coherence.** Implied population = `spend / spend_per_capita`,
  computed separately within each payer. It is the same state population, so
  under all-ages the four payers must agree. Under standardization they need not.
  Figure: cross-payer spread by basis. *This is the affirmative case for all-ages
  and it is a fact about the data, not a preference.*
- **E1.2 The counter-argument, tested.** All-ages rates are confounded by
  demographic composition only if treated and control states' age structures
  **diverged** over 2010–2018. Figure: `prop_under18` and `prop_over65` trends by
  group. If the lines are parallel, standardization is cosmetic here and the
  objection dissolves. If they fan out, it is real.
- **E1.3 How much standardization moves the data.** Overlay of standardized vs
  all-ages spend per capita, by payer, treated vs control.
- **E1.4 Does it change the answer?** Primary spec estimated on both bases;
  scatter of ATT (as % of pre-period level) with the 45-degree line.
- **E1.5 Pre-trend pass rates by basis.** Table.

**[DECISION 2] Denominator — per capita vs per beneficiary.**

- **E2.1 Is the denominator actually endogenous?** Event-study plot of enrollee
  counts by payer. If Medicaid and private enrollment move at expansion, per-
  beneficiary outcomes mix intensity with composition — shown, not argued.
- **E2.2 The two ATTs side by side** for every payer and setting, with the
  coverage effect alongside, so the identity is visible.

**[DECISION 3] Multiplicity.**

- **E3.1 p-value histogram** across the full estimated set against the uniform
  null, plus the count significant at 0.05 versus the count expected by chance.
- **E3.2 BH q-values** on the primary set.

**[DECISION 4] Out-of-pocket, given the pre-trend failure.**

- **E4.1 Raw OOP trends 2010–2013**, treated vs control. Diagnosis, not just the
  test: level shift, trend, or one bad year?
- **E4.2 Pre-trend p by payer, setting and basis** — does OOP fail on both?
- **E4.3 Event-study plot** with pre-periods shown.

**[DECISION 5] Inference.**

- **E5.1 Analytic clustered SE vs multiplier bootstrap** (`bstrap = TRUE`),
  pointwise vs uniform bands, on the primary set. Table flagging any conclusion
  that flips.

### (c) Proposed expansions — argued for or against, Emily chooses

Rambachan–Roth sensitivity for the pre-trend concern; never-treated-only control
group stated explicitly; the 1115-waiver exclusion; staggered sample as a
robustness panel.

**Gate: Emily reviews the evidence pack and answers Decisions 1–5.**

## Stage 2 — Final estimation  *(~45 min)*

Smaller than originally planned, because Stage 1 already fits most of it. One
script, `R/estimate.R`, run to the chosen decisions, writing one tidy overall CSV
and one event-study CSV. Anything Stage 1 fit under a rejected branch is dropped,
not carried forward.

## Stage 3 — Results review → **CHECKPOINT 3**  *(~30 min yours)*

You see the estimates and decide:

- **[DECISION 6]** The poster's central claim — null-with-bounds, or the
  decomposition/mechanism framing. Chosen with the estimates in front of you.
- **[DECISION 7]** You give me the poster template: layout, panel count,
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
| **CP2** | 1 Audit + evidence run | 120m | 30m |
| | 2 Final estimation | 45m | — |
| **CP3** | 3 Results review + template | 15m | 30m |
| **CP4** | 4 Figures and tables | 90m | 20m |
| **CP5** | 5 Poster build + defence sheet | 90m | 30m |
| | **Total** | **~6h15m** | **~2h** |

Slack is thin. If we fall behind, the first thing cut is the sensitivity suite
in Stage 2, not a checkpoint.

## Risks

1. **The corrected result may be a null**, and a null is harder to present
   than an effect. Framing decided at Checkpoint 3, not assumed here.
2. **DECISION 1 is a genuine trade-off with no free option.** If it goes to
   standardized, the mechanism story is unavailable and the poster is thinner.
3. **One day.** If Stage 1 uncovers an error deeper than the six listed, we
   re-plan rather than push through — I will say so at Checkpoint 2.
