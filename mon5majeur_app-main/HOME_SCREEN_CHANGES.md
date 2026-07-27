# Home Screen — Launch Update

_A plain-language summary of the changes made to the Home screen, based on the client's launch spec and Figma._

## Why this was done
The client asked for a set of visual updates to the Home screen ahead of launch. This round is a **look-and-feel update only** — we matched the Figma. The app's backend doesn't yet send some of the data the new design implies (whether a user has "validated" their 5-player lineup, the "Lock in XhYm" countdown, and whether a user has premium live-access), so those parts are shown with sensible placeholder values for now and clearly marked in the code so they're easy to hook up to real data later.

## What changed, in plain terms

### Things we removed
- **The "Earn 6 free tokens" badge** that used to sit at the top of the screen is gone.
- **The "NBA Global League" promo card** at the top is gone.
- **The two orange "See all matches" and "See all leagues" buttons** are gone. They're replaced by small text links in the section titles (see below).

### Section titles now have a link on the right
- The old **"My matches today"** section is renamed to **"Night's Results"**.
- Each of the two sections ("Night's Results" and "My Leagues") now has a small orange link on the right side of its title:
  - "Night's Results" → **All matches ›**
  - "My Leagues" → **All leagues ›**
- Both links use the exact same style and alignment, and they open the same full-list screens the old orange buttons used to open.

### The match card ("Night's Results")
- The status label is now only ever one of two things: **LIVE** (red) or **FINAL** (green check) — no more "Upcoming" or other labels.
- The card now shows the **score inline**: the left team's score in green, the right team's score in red, e.g. `Paris FC 83 Vs 69 Hoops FC`.
- If there's no result to show yet, a dash **"—"** appears in place of the scores.

### The league card ("My Leagues")
- The right side now shows the **lineup validation status**:
  - Not done yet → a red dot with **"Set your 5"** and a small **"Lock in 2h15"** note underneath.
  - Done → a green dot with **"5 Validated"** and a small **"Tap to edit"** note underneath.
- The **"Matchday"** label moved down into the bottom info line, which now reads:
  `#2nd of 8 teams | Regular season | Matchday 14`.

### Language support
All the new bits of text (Night's Results, All matches, All leagues, Set your 5, 5 Validated, Tap to edit, etc.) were added in **both English and French**, so nothing shows up as raw code text.

## What's a placeholder for now (needs backend later)
These are shown per the design but not yet wired to real data. Each is marked in the code with a `TODO(backend)` note:
- **LIVE vs FINAL** is currently guessed from the match's raw status. The spec wants it gated on whether the user has **premium live-access**.
- **"5 Validated" vs "Set your 5"** is currently derived from the league's active state. The spec wants the real **per-user lineup-validated** state.
- **"Lock in 2h15"** is a fixed placeholder. It should become a **real countdown** once the backend provides the lock time.
- **Scores / "—"** currently assume a result exists if a score is greater than zero. This should be driven by a **real "result available" signal**.

## Files touched
- `lib/presentation/screens/home/home_screen.dart` — all the layout and widget changes.
- `lib/core/constants/app_strings.dart` — new text keys.
- `lib/core/language/english.dart` — English translations.
- `lib/core/language/french.dart` — French translations.

## How it was checked
- Ran the code analyzer (`flutter analyze`) — **no problems** in any of the changed files.
- A full on-screen visual check still needs the app running with a logged-in account, since the Home screen loads its content from the server.

## One small note for the client
The "Regular season" text on the league card comes straight from the server as "Regular Season" (capital S), while the Figma shows a lowercase "s". Since it's real data, we left it exactly as the server sends it. We can force it to match the mockup if preferred.
