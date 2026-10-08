# GymMane Integration Plan — Recomp Protocol v1.0 → InlitX/GymMane

**Date:** 2026-10-08 · **Status:** plan only, no implementation (per your instruction)
**Companion doc:** `docs/recomp-protocol-v1.md`

---

## 1. Repo facts (verified from GitHub, 2026-10-07)

| Fact | Value |
|---|---|
| Repo | `InlitX/GymMane` — ~751 stars, ~90 forks, 179 commits |
| Latest | v1.4.0 (2026-10-02); newest commit 6e121b8 (2026-10-05, Wilks + FFMI calculators) |
| Stack | Flutter/Dart, Android 7.0+, **fully offline — no internet permission** |
| License | GPL-3.0 **+ ADDITIONAL_TERMS.md** (attribution requirements, GPLv3 §7(b) additional terms) |
| Assets | Exercise art CC BY-SA 4.0 (Bryl Lim / Everkinetic); fonts SIL OFL |
| Contribution rules | CONTRIBUTING.md: **"For anything big, open an issue first"**; translations via Crowdin (TRANSLATING.md); CREDITS.md for attribution |
| Build | `flutter pub get` → `flutter build apk --release` |

**Existing features relevant to us:**
- 500+ exercise library with animations, filters, and **custom exercises**
- **Places** — declare the equipment a location has
- **Routines** — scheduled, repeatable session templates; ready-made plans supported; "Routine with AI"
- **Calendar journal** — session logging
- **6+ calculators** — 1RM, plate math, BMI, **calories & macros**, body fat, warm-up, Wilks, FFMI
- **CSV/ZIP export/import** (Hevy, Strong, Lyfta, FitNotes, openGym formats), Strava export
- 17 languages via `lib/l10n`
- **No nutrition/food module** — this is the gap

---

## 2. Gap analysis: protocol → app

| Protocol component | Maps to | Gap? |
|---|---|---|
| Gym A/B/C sessions (Tue/Thu/Fri) | **Routines** with scheduled days | None — enter as 3 routines; all exercises exist in the 500+ library (back squat, DB bench, chest-supported row, leg curl, face pull, deadlift, lat pulldown, cable row, leg press, Bulgarian split squat, floor press, farmer's carry, calf raise) |
| Wednesday home circuit | **Routine** + a **Place** "Home (no equipment)" | None — bodyweight variants exist; add custom exercises only if an item (prone Y-T raise) is missing |
| Judo Monday | Journal entry / optional custom activity | Cosmetic only |
| TU Delft X kit | **Place** with equipment declared | None |
| Progression rules (double progression, RIR) | Journal per-set logging | Partial — RIR/RPE is not a first-class field (upstream candidate) |
| 4 meal slots, gram-exact foods, daily macro targets | **Nothing** | **Full gap — the nutrition module** |
| Grocery list from meal plan | Nothing | Gap — depends on nutrition module |
| Macro calculator | Exists (calculators) | Static calculator, not tied to a food log |
| 14-day weight average / adjustment rules | Body-weight tracking exists in calculators context | Trend view is the missing piece |
| Batch-cook scheduling | Nothing | Out of scope — keep on paper |

**Conclusion:** training needs **zero code** — it's a data-entry exercise using existing Routines/Places. The real project is a **nutrition module** (foods, meal plans, daily log, grocery aggregation), which does not exist in any form.

---

## 3. Strategy: two tracks, one fork

**Track 1 — Personal fork (do first, private):** fork `InlitX/GymMane`, enter the training plan as data, and build the nutrition module for personal use. Fast value, no coordination cost, freedom to hardcode personal foods.

**Track 2 — Upstream proposal (after Track 1 stabilises):** per CONTRIBUTING.md, **open an issue first** with a design proposal for a generalised nutrition module. Only generalised, data-driven code goes upstream — no personal meal plans, no Telangana spice tables, no Delft prices.

This order matters: upstream-first would stall on design debate while the protocol needs a log *today*; fork-first without an issue would violate the project's stated contribution etiquette for anything big.

---

## 4. Track 1 — Personal fork, phased

### Phase 0 — Fork & baseline (½ day)
- Fork, `flutter pub get`, `flutter build apk --release`, sideload APK — confirm build chain works before touching anything.
- Create branch `nutrition-local` off the release tag (v1.4.x), not `main`'s HEAD, to avoid churn under a moving upstream.
- **Data entry (no code):**
  - Places: "TU Delft X" (full kit) and "Home" (bodyweight only).
  - Routines: `Gym A — Squat & Press` (Tue), `Gym B — Deadlift & Pull` (Thu), `Gym C — Single-leg` (Fri), `Home Circuit` (Wed), each with the exact sets/reps/rest from the protocol; custom exercises for any gap (check prone Y-T raise).
  - Journal habit: log load × reps × RIR (RIR in the set note until it's a real field).

### Phase 1 — Nutrition data layer (~1–2 weekends)
- **Local storage mirroring existing app patterns** (whatever the routines/journal use — match it; likely Hive/SQLite via existing repositories).
- Entities (plan-level only, no code yet):
  - `FoodItem` — name, per-100 g (kcal, P, C, F, fibre), category, editable; seed with Appendix A of the protocol (17 foods) + manual entry.
  - `MealSlot` — name, time hint (B/L/D/S).
  - `MealPlanDay` — slots → list of (FoodItem, grams).
  - `IntakeLog` — date, slot, food, grams actually eaten (default = plan, editable per day).
  - `MacroTarget` — kcal/P/C/F/fibre targets + date-range validity (so the 1,800 → 1,900 switch per protocol §8 is a target change, not a code change).
- Import path: CSV of the protocol's Appendix A table (the app already has CSV infrastructure to imitate).

### Phase 2 — Nutrition UI (~2–3 weekends)
- **Today view:** 4 slot cards showing planned grams; tap to adjust; running daily totals vs targets (kcal/P/C/F/fibre) with the same visual style as existing calculators.
- **Plan editor:** edit gram amounts per slot; "duplicate day" for the 2 identical batch days.
- **Weight trend:** daily weight entry + **14-day moving average** line (the protocol's only valid signal); simple flag when the average leaves the ±0.4 kg band (adjustment rules from §8 as helper text, not automation).
- Optional: grocery list = 14-day plan × per-100 g quantities, aggregated per food, plain text share.

### Phase 3 — Hardening (ongoing)
- Golden tests for macro math (the same totals as `recomp/verify_macros.py`: 1,788 / 126.5 / 246.2 / 30.5 / 30.0 — the script doubles as the test oracle).
- Export intake log to CSV alongside the existing export system.
- Keep rebasing `nutrition-local` onto upstream releases; the module is additive so conflicts should be rare.

---

## 5. Track 2 — Upstream proposal (issue-first)

**Issue to open (after Phase 1 proves the data model, ~4–6 weeks in):**
> "Proposal: offline nutrition module — foods, meal plans, daily intake log, macro targets"

Contents that make it mergeable by a GPL offline-first project's standards:
1. **Motivation:** the app has a calories-&-macros calculator but no persistence; logging is the #1 missing piece for any diet-aware training log (offline, no account, no internet permission — same principles).
2. **Scope, deliberately small for v1:** user-editable food DB + CSV import; meal plans as templates; daily log; totals vs targets. **Explicit non-goals:** barcode scanning (needs internet/licensed DB — violates the offline principle), branded-food APIs, AI food detection.
3. **Data model:** the Phase 1 entities, generalised — no personal data, no prices, no hard-coded foods beyond a tiny optional seed set (licensing: USDA FoodData Central is public domain; NEVO is CC-BY — cite per CREDITS.md conventions).
4. **Integration points:** reuse the existing macro calculator logic; mirror the existing CSV import/export UX; extend the existing local DB; add strings to `lib/l10n` via Crowdin (do **not** hand-edit 17 translation files — TRANSLATING.md governs this).
5. **License hygiene:** all new code GPL-3.0-compatible; no GPL-incompatible deps; new assets only CC BY-SA 4.0 or original; attribution additions to CREDITS.md.
6. **Tests:** golden tests for macro arithmetic; widget tests for the today view.

**Follow-ups after the core lands (separate issues, each small):**
- RIR/RPE as a first-class set field in the journal.
- Weight 14-day moving average view.
- Grocery-list aggregation from a meal plan.

**Acceptance reality:** a module this size may never merge, or may be redirected by the maintainer into a different shape. That's fine — Track 1 already delivers the personal value; the issue documents the design either way.

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Upstream moves fast (commits weekly) | Branch off release tags; keep the module in its own directory/files; additive changes only |
| Maintainer rejects nutrition scope | Track 1 is self-sufficient; fork keeps working regardless |
| Personal foods leak into an upstream PR | Separate branch hygiene: `nutrition-local` never pushed as PR source; upstream work happens on clean feature branches from `main` |
| ADDITIONAL_TERMS.md obligations | Read it in full before the first PR; it adds attribution duties beyond bare GPLv3 |
| Flutter build chain on my machine | Phase 0 gate — nothing else starts until the APK builds |

## 7. Explicit non-goals

- No implementation in this phase (your instruction).
- No server, no sync, no accounts — the app's offline-only principle is a feature, not a limitation to fix.
- No barcode/branded-food database.
- No automation of the §8 adjustment decisions — the app shows the 14-day average; a human makes the call.
