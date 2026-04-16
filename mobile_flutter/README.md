# MuslimAI Flutter

`mobile_flutter/` is the new mobile direction for this repo. It replaces Expo as the active path for Android and iOS work while keeping the old React Native app available as reference during migration.

## What is in this first pass

- Flutter app shell with five screens:
  - Home
  - Prayer
  - Quran
  - Library
  - More
- Prayer times and qibla from AlAdhan
- Quran chapter list, Arabic text, translations, and recorded reciter audio from Quran.com
- Local Adhkar and Hisn Muslim snapshots bundled as Flutter assets
- Arabic-first rendering for Quran and remembrance text

## Run locally

```bash
cd mobile_flutter
flutter pub get
flutter run
```

## Current scope

- Quran:
  - `Read only`
  - `Listen only`
  - `Read + listen`
- Prayer:
  - manual coordinates
  - date selection
  - qibla direction
- Library:
  - Hadith remote fetch with fallback
  - Adhkar snapshot-backed
  - Hisn Muslim snapshot-backed

## Deliberate gaps

- Adhkar listen modes are not using TTS in Flutter.
- Native-speaker recorded adhkar audio still needs to be added.
- Offline storage, bookmarks, notifications, and background audio are not wired yet.

## Recommended next steps

1. Add a repository/cache layer with `shared_preferences` or a local database.
2. Add device geolocation to Prayer.
3. Add proper background audio controls for Quran.
4. Add recorded adhkar audio assets and sync logic.
5. Port any remaining web-only Islamic features once the core mobile loops are stable.
