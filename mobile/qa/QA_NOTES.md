# Mobile QA Notes

Date: `2026-04-12`

## Scope

Visual QA pass performed on:

- iOS simulator
- Android emulator

## Captured screenshots

- [ios-quran-pre-fix.png](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/qa/screenshots/ios-quran-pre-fix.png)
- [ios-home-post-fix.png](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/qa/screenshots/ios-home-post-fix.png)
- [android-redbox-pre-fix.png](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/qa/screenshots/android-redbox-pre-fix.png)
- [android-home-post-fix.png](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/qa/screenshots/android-home-post-fix.png)

## Findings

1. Android Expo Go was initially crashing on launch because `expo-notifications` was being used in a path that Expo Go no longer supports on Android.
2. iOS top chrome was too close to the notch / dynamic island. The top safe area padding was insufficient.
3. After fixes, both simulators rendered the app successfully and the home screen layout is now stable on both platforms.

## Fixes applied during QA

1. Added Expo Go guards around notification automation so prayer reminders degrade gracefully instead of crashing.
2. Added Expo Go guards around lock-screen audio metadata calls.
3. Added safe-area top and bottom spacing to the mobile screens so content clears the notch and bottom system areas more reliably.

## Remaining visual observations

1. The floating settings button at the top right still feels visually heavy relative to the editorial layout and may need size or shadow tuning.
2. The bottom tab bar icon labels are readable, but the inactive states are close to the edge of low-contrast territory on some light backgrounds.
3. Only the home screen and one Quran screen were visually inspected in this pass. Prayer, Library, and More still need a dedicated screenshot-by-screenshot review.
