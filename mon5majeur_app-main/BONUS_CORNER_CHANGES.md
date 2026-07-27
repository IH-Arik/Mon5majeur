# Bonus Corner & Change-Bonus Changes

## Client request
> "bonus have to stay on the top right and corner. If i click on this i can change bonus."

Reference mockup: `~/Downloads/Bonus Activated.png` (right phone).

## Confirmed behavior
1. **One bonus active at a time** — activating a bonus replaces the previous one.
2. The **top-right corner shows the active bonus's icon**; tapping it reopens the menu
   so the user can **change** the bonus. With nothing active it keeps the generic
   "+ Bonuses" box.
3. The **"X Bonus Activated"** label below the court is **persistent** (no longer a
   3-second flash).

## Scope
All changes are in a single file:
`lib/presentation/screens/home/tabs/build_your_team_tab.dart`

- The global-league tab (`build_your_team_global_tab.dart`) has no bonus UI and was
  **not** touched.
- No backend/API changes — bonus activation is client-side only (the team submission
  payload never sends bonus data). Only the locally displayed charge counts (loaded from
  `/api/bonuses/my-inventory/`) are adjusted.

## What changed

### 1. Single active-bonus model
- Added a top-level enum: `enum BonusType { sixthMan, chefsCurry, luxuryTax }`.
- Added state field: `BonusType? activeBonus;` (null = none).
- Replaced the three boolean fields `sixthManActivated / chefsCurryActivated /
  luxuryTaxActivated` with **derived getters** so all existing read-sites keep working
  (on-court 6th-man slot guard, menu `isActivated` highlighting):
  ```dart
  bool get sixthManActivated  => activeBonus == BonusType.sixthMan;
  bool get chefsCurryActivated => activeBonus == BonusType.chefsCurry;
  bool get luxuryTaxActivated  => activeBonus == BonusType.luxuryTax;
  ```
- Removed the temporary-message flags `showSixthManMessage / showChefsCurryMessage /
  showLuxuryTaxMessage`.

### 2. `_selectBonus(BonusType)` replaces the three `_activate…` methods
Implements activate + change semantics:
- Tapping the **already-active** bonus closes the menu; for 6th Man it re-opens the
  substitute player picker (`_selectSixthMan()`).
- Tapping a **different** bonus (requires a charge > 0): in one `setState`, refunds the
  previously active bonus's charge (+1), sets `activeBonus`, consumes the new one (-1),
  and closes the menu.
- Switching **away from** 6th Man clears `sixthManPlayer` so the on-court 6th-man slot
  disappears cleanly. Switching **to** 6th Man opens the player picker.
- Added helpers `_availableFor(BonusType)` and `_adjustCharge(BonusType, delta)` for the
  per-type charge counts (`sixthManAvailable / chefsCurryAvailable / luxuryTaxAvailable`).

### 3. Corner button reflects the active bonus (`_buildBonusButton`)
- No bonus active: unchanged "+ / Bonuses" box.
- Bonus active: renders that bonus's icon (`Assets.icons.sixman / .chefcurry /
  .luxarytax`) inside the same 42x42 top-right box. Tap still toggles the menu — this is
  the "click to change" entry point. Added getter `_activeBonusIcon`.

### 4. Persistent activated label (`_buildActivatedBonuses`)
- Rewritten to render a **single** row driven by `activeBonus` (icon + matching string:
  `sixthManBonusActivated / chefsCurryBonusActivated / luxuryTaxBonusActivated`, with
  existing colors — blue `0xFF2941F1`, gold `0xFFFECD56`, green `0xFF3CDF1C`).
- Returns `SizedBox.shrink()` when no bonus is active. The 3-second `Future.delayed`
  auto-hide was removed.

### 5. Menu item taps wired
- In `_buildBonusOptionsMenu`, each item's `onTap` now calls
  `_selectBonus(BonusType.…)` instead of the old `_activate…` methods.

## Verification done
- `flutter analyze lib/presentation/screens/home/tabs/build_your_team_tab.dart` →
  **No issues found**.
- Grep confirmed no stale references to the removed fields/methods
  (`showSixthManMessage`, `_activateSixthMan`, etc.).

## Manual test steps (not yet run in-app)
1. Top-right box shows "+ Bonuses" initially.
2. Tap it → menu → pick **6th Man** (needs a charge; buy in Shop if count is 0). Corner
   shows the 6th Man icon, on-court 6th-man slot + player picker appear, and "6th Man
   Bonus Activated" shows **and stays** below the court.
3. Tap the corner icon → pick **Chefs Curry**. 6th Man slot disappears, 6th Man count
   goes back up by 1, Chefs Curry count drops by 1, corner shows the Chefs Curry icon,
   and the label switches to "Chefs Curry Bonus Activated" persistently.
4. Tap the corner icon → tap the already-active bonus → menu just closes (6th Man
   re-opens the player picker).
