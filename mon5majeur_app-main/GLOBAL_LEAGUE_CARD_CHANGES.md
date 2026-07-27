# Home Screen — Global League Status + Stats Card

_A plain-language summary of the changes made to add the Global League card on the Home screen, based on the client's "Home page after JOIN GLOBAL LEAGUE" spec and screenshot._

## Why this was done

The client asked that, after a user joins the Global League, the Home screen show a
**status + stats card** instead of a plain "Join now" call-to-action. The problem: with
only a "Join now" style card you can't tell your status or what to do at a glance. The
new card surfaces your stats plus a clear team-status/CTA, and tapping it opens the team
builder where you set your 5 players.

Note: there was actually **no** existing Global League card or "Join now" card in the app
(the strings existed but were unused), so this was built as a **new card** rather than a
replacement of an existing one.

## What changed, in plain terms

### New "NBA Global League" card (top of Home)
A new card now sits at the very top of the Home screen, above the "Join the League" /
"Create a league" buttons. It uses the same dark, rounded card look and the same
fade/slide entrance animation as the other Home cards.

The card has a title ("NBA Global League" in orange) and two columns:

- **Left — stats:**
  - `Night Score <points> pts` — shows a dash "—" until the score is available.
  - `Weekly #—` — placeholder for now.
  - `Monthly #—` — placeholder for now.

- **Right — team status / CTA:**
  - Lineup **not** set yet → a red dot with **"Set your 5"** and a small **"Lock in 2h15"** note.
  - Lineup set → a green dot with **"5 Validated"** and a small **"Tap to edit"** note.

### Interaction
- **Tapping anywhere on the card** opens the Global League team builder (the screen where
  the user sets their 5 players).

### Language support
- Added one new text label, **"Night Score"**, in both English ("Night Score") and French
  ("Score du soir"). All other labels reuse text that already existed in the app.

## What's live vs. placeholder (needs backend later)
The card uses real data where the app already provides it, and placeholders elsewhere.
Each placeholder is marked in the code with a `TODO(backend)` note:

- **Night Score** — live from the Global League controller's total points; shows "—" when
  no selection is loaded yet.
- **"5 Validated" vs "Set your 5"** — currently derived from whether 5 players are picked.
  The spec wants a real per-user "lineup validated / locked" flag.
- **Weekly # / Monthly #** — placeholders ("—"). No ranking data exists in the app yet.
- **"Lock in 2h15"** — a fixed placeholder. It should become a real countdown once the
  backend provides the lock time.

## Files touched
- `lib/presentation/screens/home/home_screen.dart` — new `_GlobalLeagueCard` widget and its
  placement at the top of the Home content.
- `lib/core/constants/app_strings.dart` — new `nightScore` text key.
- `lib/core/language/english.dart` — English translation ("Night Score").
- `lib/core/language/french.dart` — French translation ("Score du soir").

## How it was checked
- Ran the code analyzer (`flutter analyze`) on all four changed files — **no issues**.
- Confirmed the Global League controller is registered for dependency injection, so the
  card can read its data at runtime.
- A full on-screen visual check still needs the app running with a logged-in account, since
  the Home screen loads its content from the server.
