# Fork notes — nutrition-local branch

Personal fork of [InlitX/GymMane](https://github.com/InlitX/GymMane)
(v1.4.0, commit 6e121b8, 2026-10-05) adding the offline nutrition module
described in `docs/gymmane-integration-plan.md` (Phase 0–2).

**Based on GymMane by InlitX** — GPL-3.0-only + the attribution term in
`ADDITIONAL_TERMS.md`, which this fork keeps (see the About screen and
`CREDITS.md`).

## What was added

| File | Purpose |
|---|---|
| `lib/models/nutrition.dart` | FoodItem, PlannedItem, MealSlot, MacroTargets, IntakeDay, MacroTotals + the seed set (Recomp Protocol v1.0 foods & 4-slot plan) |
| `lib/state/nutrition_state.dart` | NutritionState mixin: macro math, plan editing, per-day intake overrides, 14-day weight moving average + §8 band check, 14-day grocery aggregation, JSON persistence |
| `lib/screens/nutrition_screen.dart` | 4-tab screen: Today (intake vs targets), Plan editor, Trend (14-day average), Grocery (shareable list) |
| `lib/state/fit_state.dart` | wiring: import, part, mixin, load/save hooks |
| `lib/app/app_shell.dart` | `nutrition` route |
| `lib/screens/tools_screen.dart` | entry card ("Nutrition — meals, macros, grocery list") |
| `test/nutrition_test.dart` | 7 tests incl. golden totals from `recomp/verify_macros.py` (1,788 kcal / P 126.5 / C 246.2 / F 30.5 / fibre 30.0) |
| `CREDITS.md` | attribution for the module and food-composition sources (USDA FDC, NEVO) |

Design rules kept: no network, no accounts, no new dependencies, additive
changes only — upstream code paths are untouched apart from the wiring lines
above.

**Strings** go through the existing ARB/l10n flow (`t.nutrition*`), because
`test/i18n_test.dart` fails the build on hard-coded English in `lib/screens`,
`lib/widgets` and `lib/app`. The 18 new keys are seeded with English values in
all 17 locales, so every locale currently shows English on the nutrition
screen; a real upstream PR would send those keys to Crowdin for translation
instead (see CONTRIBUTING.md).

## Verified

Flutter 3.47.6 / Dart 3.13.5, 2026-10-08:

- `flutter analyze --no-pub` — 0 issues from this branch's code. The 2
  remaining `info` lines (`onReorder` deprecation in `routine_edit_screen.dart`
  and `session_screen.dart`) are pre-existing upstream.
- `flutter test test/nutrition_test.dart` — 7/7 pass, golden totals matching
  the Python oracle exactly (1,788 kcal; Atwater cross-check 1,766).
- Full `flutter test --concurrency=1` — 608 pass / 3 skip / 0 fail, exit 0.
  The single failure in an earlier run was `i18n_test.dart` flagging my
  hard-coded strings; fixed by moving them into the ARB keys.
  (`--concurrency=1` matters here: the default parallel compiler gets
  OOM-killed on a 2 GB sandbox.)

## Uploading to your GitHub

The downloadable zip (`gymmane-nutrition-fork.zip`) contains the full source
tree but **not** the `.git` folder (upstream history is ~113 MB and would
bloat the download). On your own machine:

```bash
unzip gymmane-nutrition-fork.zip
cd gymmane
git init -b nutrition-local
git add -A
git commit -m "Add offline nutrition module (Recomp Protocol v1.0 seed plan)"
# On github.com: create a new EMPTY repository (no README/license), then:
git remote add origin git@github.com:<you>/GymMane.git
git push -u origin nutrition-local
```

The GPL-3.0 obligations travel in the files, not the history: keep
`LICENSE`, `ADDITIONAL_TERMS.md` and `CREDITS.md` in the public repo (they
are included), and keep the About screen's "Based on GymMane by InlitX"
attribution (untouched).

If you would rather keep the full upstream history, clone
`https://github.com/InlitX/GymMane` yourself and copy these paths over it:
`lib/models/nutrition.dart`, `lib/state/nutrition_state.dart`,
`lib/screens/nutrition_screen.dart`, `test/nutrition_test.dart`,
`FORK-NOTES.md`, `CREDITS.md`, `docs/recomp-protocol-v1.md`,
`docs/gymmane-integration-plan.md`, `recomp/`, `lib/l10n/` (the regenerated
files), plus the small edits in `lib/state/fit_state.dart`,
`lib/app/app_shell.dart` and `lib/screens/tools_screen.dart` (see
`git show` of the nutrition commit if you have it, or diff against upstream).

## Upstream proposal (Track 2, later)

Per CONTRIBUTING.md: **open an issue first** before any PR. The module here
is already data-driven and generalised (the protocol plan is seed *data*,
not hard-coded logic), but strip personal specifics (shop names, prices)
from anything you propose upstream, and move the UI strings into the Crowdin
`.arb` flow instead of hard-coded English.
