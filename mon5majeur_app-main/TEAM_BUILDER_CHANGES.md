# Team Builder — 3 Confirm States + Remove Ads (Changes)

## Summary

Implemented the client's "Team builder — 3 states (CTA + color)" spec everywhere a
lineup is confirmed (Global + Private/Public leagues), and hid the ad-related shop
surfaces behind a reversible feature flag ("remove ads for launch, add back later").

---

## The 3 states

| State | Condition | Banner | Button label | Button color | Enabled |
|-------|-----------|--------|--------------|--------------|---------|
| INCOMPLETE | players_selected < 5 | red "You need X more players" | "Confirm my team" | Grey | disabled |
| READY | == 5 && !is_confirmed | green "Team complete" | "Confirm my team" | Orange | enabled |
| CONFIRMED | == 5 && is_confirmed | green "Team complete" | "Team confirmed" | Green | disabled |

**Rule:** any edit to the lineup after confirmation sets `is_confirmed = false` and
returns to the orange READY state. While a save is in flight, the button shows the
grey + spinner treatment.

### Decisions (confirmed with product)
- **`is_confirmed`: client-side only.** No backend field exists — confirming is just a
  POST of `selected_players`. A saved/just-submitted 5-player lineup counts as
  confirmed (green); any edit reverts to orange.
- **`lock_time`: deferred.** No real lock-time data exists yet. States are driven by
  players_selected + is_confirmed only. The existing "4 Hours Left" placeholder stays.
  The state helper leaves a marked spot to add `now < lock_time` later.
- **Ads: hidden reversibly** behind a feature flag, not deleted.

---

## Files changed

### New: `lib/presentation/screens/home/tabs/team_confirm_controls.dart`
Shared widgets used by both team-builder tabs to avoid drift:
- `enum LineupState { incomplete, ready, confirmed }`
- `lineupStateFor({selectedCount, isConfirmed})` — state calc (with a comment marking
  where the future `now < lockTime` gate slots in).
- `TeamStatusBanner` — green "Team complete" / red "You need X more players".
- `TeamConfirmButton` — grey/orange/green gradient, correct enabled + label per state,
  spinner while submitting.
- `showTeamValidatedDialog(context)` — the centered "Team validated!" popup with green
  check + OK button (matches the 3rd mockup screen).

### New: `lib/core/constants/feature_flags.dart`
- `const bool kAdsEnabled = false;` — flip back to `true` to restore ad surfaces.

### `lib/presentation/screens/home/tabs/build_your_team_tab.dart` (Private/Public)
- Added `bool isConfirmed = false;`.
- `_fetchSavedTeam()` — sets `isConfirmed = true` when a complete 5-player saved team loads.
- `_selectPlayer` / `_selectSixthMan` `onPlayerSelected` — set `isConfirmed = false` on edit.
- `_submitPlayerSelection()` success — sets `isConfirmed = true` and shows the
  "Team validated!" dialog (replaced the old "Team saved successfully!" snackbar).
- build() — replaced inline banner + confirm button with `TeamStatusBanner` /
  `TeamConfirmButton`; removed the now-unused `_buildTeamStatus()` method.

### `lib/presentation/screens/home/tabs/build_your_team_global_tab.dart` (Global)
- Mirrored all of the above:
  - Added `bool isConfirmed = false;`.
  - `_loadExistingSelection()` — sets `isConfirmed = true` when a complete team loads.
  - `onPlayerSelected` — resets `isConfirmed = false` on edit.
  - `_saveTeam()` success — sets `isConfirmed = true` and shows the "Team validated!"
    dialog (replaced the green snackbar).
  - build() — replaced banner + button (button still wrapped in `Obx` so
    `_controller.isSaving` drives the spinner); removed the unused `_buildTeamStatus()`.

### Strings — `lib/core/constants/app_strings.dart`, `lib/core/language/english.dart`, `lib/core/language/french.dart`
Added three keys (EN / FR):
- `confirmMyTeam` — "Confirm my team" / "Confirmer mon équipe"
- `teamConfirmed` — "Team confirmed" / "Équipe confirmée"
- `teamValidated` — "Team validated!" / "Équipe validée !"
Reused existing `teamComplete` and `youNeedMorePlayers(n)` for the banner.

### Ads — `lib/presentation/screens/shop/shop_screen.dart`
- Imported the feature flag.
- Gated the "watch a rewarded ad -> +6 tokens" daily-video button behind `if (kAdsEnabled)`.
- Gated the "Stop-Pub / Remove all ads" card (and its trailing spacer) behind `if (kAdsEnabled)`.
- `shop_controller.dart` `earnDailyVideoTokens()` and the `stopPubActive` model field were
  left untouched (dead but harmless; restored by flipping the flag). No backend changes.

---

## Out of scope / notes
- `home_screen.dart` `_validationStatus()` (home lineup card) still uses a
  `selectedPlayers.length >= 5` proxy with a `TODO(backend)`. It is not a confirm surface —
  left as-is.
- No backend changes. A persisted `is_confirmed` and a real `lock_time` remain future work;
  the state helper is written so the lock check can be added later.

---

## Verification status
- `flutter analyze` passes on all changed files ("No issues found"). Remaining project-wide
  lints are pre-existing `info`-level warnings in unrelated files.
- End-to-end run NOT performed — reaching the confirm screen needs a device/emulator plus
  backend auth and real league/player data.

### Manual test checklist (when running the app)
In **both** a Private/Public league and the Global league:
1. <5 players -> grey disabled "Confirm my team" + red "You need X more players".
2. Fill 5 players -> orange enabled "Confirm my team" + green "Team complete".
3. Tap Confirm -> "Team validated!" dialog -> button turns green disabled "Team confirmed".
4. Edit any slot -> button returns to orange "Confirm my team" (is_confirmed reset).
5. Re-open the screen after confirming (re-fetch) -> loads as green "Team confirmed".
6. Shop screen -> "+6 tokens" watch-ad button and "Stop-Pub" card are gone; setting
   `kAdsEnabled = true` brings them back.
