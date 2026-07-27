# Notification Pop-up Changes

Post-validation pop-ups on the "Build your team" screen.

## Requirement

1. **Pop-up 1 — Notifications opt-in.** Shown **only after the user validates their
   first team** (moved out of onboarding). Copy + two buttons: **Not now** / **Enable**.
   If the user declines, don't ask again. Tapping **Enable** triggers the real OS
   notification-permission prompt.
2. **Pop-up 2 — "✅ Team validated!" success feedback.** Shown after **every** successful
   validation. OK button, no auto-dismiss.

**Pop-up 2 already existed** (`showTeamValidatedDialog`) and already met the spec — no change.
The new work is Pop-up 1.

> Note: There is no push backend yet (no Firebase Messaging / device-token registration).
> "Enable" only secures the OS permission; actual push delivery is out of scope.

## Files changed

### 1. `lib/core/constants/api_constants.dart` (new storage key)
Added one flag to `AppConstants`:
```dart
static const String notificationPromptHandled = 'notification_prompt_handled';
```
A single flag covers both rules: unset until the first validation (so the prompt fires
"after the first team"), set to `true` the moment the user picks either button (so it
never shows again).

### 2. `lib/core/constants/app_strings.dart` (new string keys)
```dart
static const String enableNotificationsTitle = "Enable notifications?";
static const String enableNotificationsBody =
    "Get your team results and a reminder before lineup lock";
static const String notNow = "Not now";
static const String enableAction = "Enable";
```

### 3. `lib/core/language/english.dart` + `lib/core/language/french.dart` (translations)
Added the same four keys to both maps.
- EN: "Enable notifications?" / "Get your team results and a reminder before lineup lock"
  / "Not now" / "Enable"
- FR: "Activer les notifications ?" / "Recevez vos résultats et un rappel avant le
  verrouillage" / "Plus tard" / "Activer"

### 4. `lib/core/services/notification_service.dart` (new file)
Wrapper around `permission_handler` that fires the OS notification-permission prompt:
```dart
Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  return status.isGranted;
}
```

### 5. `lib/presentation/screens/home/tabs/team_confirm_controls.dart` (dialog + gate)
Added imports for `get`, `api_constants.dart`, `local_db.dart`, `notification_service.dart`.
Added two functions next to the existing `showTeamValidatedDialog`:
- `showEnableNotificationsDialog(context)` — the "Enable notifications?" pop-up (bell icon,
  title, body, grey **Not now** / orange **Enable**), styled to match the success dialog.
  Returns `true` if the user tapped Enable, else `false`.
- `maybeShowNotificationPromptAfterFirstValidation(context)` — the first-time gate:
  reads `notificationPromptHandled`; if already handled, returns; otherwise marks it
  handled, shows the pop-up, and if the user tapped Enable, calls
  `requestNotificationPermission()`.

New strings use `.tr` so they localize (EN/FR).

### 6. Success branches wired up (success dialog first, then prompt)
- `lib/presentation/screens/home/tabs/build_your_team_tab.dart` (`_submitPlayerSelection`,
  200-response branch) — now `await showTeamValidatedDialog(context)` then
  `await maybeShowNotificationPromptAfterFirstValidation(context)`.
- `lib/presentation/screens/home/tabs/build_your_team_global_tab.dart` (`_saveTeam`,
  success branch) — same change.

Because the gate flag is shared, whichever tab produces the user's first-ever validation
shows the prompt; neither shows it again.

### 7. `ios/Podfile` (iOS build config for permission_handler)
Added to `post_install` so the notification-permission API compiles on iOS:
```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_NOTIFICATIONS=1',
]
```

## Out of scope
- Actual push delivery (Firebase Messaging / device-token registration).
- Pop-up 2 — already implemented, unchanged.

## Verification
- `flutter analyze` on all changed files: **no issues**.
- Manual (needs a device/simulator + a logged-in user hitting a successful validation):
  1. Fresh install (or clear the `notification_prompt_handled` pref).
  2. Build a valid 5-player team → tap **Confirm My Team** → "Team validated!" (closes only
     on **OK**) → then "Enable notifications?" appears.
  3. Tap **Enable** → OS notification-permission dialog appears.
  4. Validate again → only "Team validated!" shows; the notification prompt does not reappear.
  5. Repeat the first-validation case but tap **Not now** → prompt does not reappear later.
- iOS: run `pod install` to pick up the new Podfile macro.

## Known pre-existing issue (left alone)
The existing success dialog uses `AppString.teamValidated` **without** `.tr`, so it always
renders English even in French. This is a pre-existing gap outside this task's scope.
