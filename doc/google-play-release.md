# Google Play Release Guide

This document records the current Android release state for `MuslimAI` and the exact steps needed to ship it through Google Play.

## Current Release State

- Flutter app path: `mobile_flutter/`
- Android application ID: `ca.geointel.muslimai`
- Android app label: `MuslimAI`
- Current version: `1.0.0+1`
- Signed bundle artifact:
  - `mobile_flutter/build/app/outputs/bundle/release/app-release.aab`

## Local Signing Setup

Release signing is wired in:

- `mobile_flutter/android/app/build.gradle.kts`
- `mobile_flutter/android/key.properties`
- `mobile_flutter/android/upload-keystore.jks`

Important:

- `key.properties` and `upload-keystore.jks` are local secrets and must not be committed.
- `android/.gitignore` already excludes them.
- Back them up outside the repo before using Google Play production tracks.

## Upload Certificate Fingerprints

Upload key alias: `upload`

- SHA1: `ED:CD:AE:D8:9B:A2:5F:E1:5F:4F:C2:14:4E:E8:B5:4C:AE:18:DB:66`
- SHA256: `06:96:45:8C:C5:AE:B5:30:38:44:9D:59:93:68:5E:14:5E:E8:CF:53:EA:6A:2A:CD:F9:24:93:3B:71:D0:89:9D`

Use these if Google Play, Firebase, or Google APIs ask for signing certificate fingerprints.

## Build Command

From the repo root:

```bash
cd mobile_flutter
flutter build appbundle --release
```

Current validated result:

- bundle builds successfully
- output file is `build/app/outputs/bundle/release/app-release.aab`

## Google Play Console Steps

1. Open Google Play Console.
2. Create the app if it does not already exist.
3. App name: `MuslimAI`
4. Default language: `English (United States)` unless product strategy changes.
5. App or game: `App`
6. Free or paid: choose the intended commercial model.
7. In `Dashboard` or `Production`, create a new release.
8. Upload:
   - `mobile_flutter/build/app/outputs/bundle/release/app-release.aab`
9. Save and continue through:
   - App content
   - Privacy policy
   - Data safety
   - Target audience
   - Ads declaration
   - Content rating
10. Submit for review when all required checks are green.

## Store Listing Draft

### App name

`MuslimAI`

### Short description

`Quran, prayer times, qibla, adhkar, and daily Islamic guidance in one mobile app.`

### Full description

`MuslimAI is an Islamic companion app designed to support daily worship with a clear, modern, and Arabic-friendly experience. It brings together Quran reading and listening, prayer times, qibla direction, adhkar, and Hisn Muslim in one mobile app for Android devices.

Read the Quran in an organized way, listen to recitation by selected sheikhs, or follow along in read-and-listen mode with synchronized verse highlighting. Track your local prayer schedule, check qibla direction, and access daily adhkar with a clean interface designed for both reading and listening.

MuslimAI includes:

- Quran reading with translation support
- Quran audio recitation by selected sheikhs
- Read-only, listen-only, and read-while-listening Quran modes
- Prayer times based on saved or current location
- Qibla direction
- Adhkar library with Arabic-first presentation
- Hisn Muslim access
- Persistent playback and saved reading state

MuslimAI is built to help users stay connected to Quran, salah, and daily remembrance through a focused and accessible mobile experience.`

## Assets To Reuse

Existing mobile screenshots are already in the repo and can be reused or adapted for Google Play listing work:

- `mobile_flutter/qa/app_store_screenshots/iphone-14-plus/`
- `mobile_flutter/qa/app_store_screenshots/ipad-pro-12.9/`
- `mobile_flutter/qa/screenshots/`

These are not ideal final Play Store assets because Google Play usually benefits from Android-native screenshots. A dedicated Android listing capture pass is recommended before production submission.

## Current Boundary

The Android bundle is built locally and ready for upload.

What still requires external account access:

- authenticated Google Play Console session
- creation or selection of the Play Console app record
- actual release upload and submission

Without Play Console access, the build can be prepared but not distributed.
