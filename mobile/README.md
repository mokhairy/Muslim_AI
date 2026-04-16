# Muslim AI Mobile

This Expo client is now legacy reference code. Active mobile development has moved to [mobile_flutter](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile_flutter).

This directory contains the native mobile client for `Muslim_AI`, built with Expo and React Native so the same codebase can target Android and iOS.

## Start here

For the exact simulator and device workflow that was verified on this machine, read [SETUP.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/SETUP.md) first.

## What is implemented

- Bottom-tab mobile shell with dedicated screens for:
  - Home
  - Prayer Times + Qibla
  - Quran reader / listener
  - Knowledge Library
  - Radio and platform notes
- Quran modes:
  - Read
  - Listen
  - Read + Listen
- Sheikh picker and translation picker
- Ayah-level recitation playback with active-ayah highlighting
- Prayer time lookup by date and coordinates
- Current-location support for prayer lookup
- Hadith, Azkar, Hisn Muslim, and Radio data integrations

## Why this architecture

The current web app is server-rendered Django, but most feature data already comes from external Islamic APIs. For mobile, the clean path is a dedicated client that talks to those same upstream services directly instead of wrapping Django templates in a WebView.

That keeps:

- Android and iOS on one shared codebase
- mobile UI native instead of browser-shaped
- data behavior aligned with the web app
- the door open for future shared backend APIs if you want stronger control later

## Run locally

```bash
cd mobile
npm install
npx expo start
```

Then press:

- `i` for iOS simulator
- `a` for Android emulator
- or scan the QR code with Expo Go

## Verified host setup on this machine

The mobile client was prepared against these local host tools:

- Xcode.app selected through `DEVELOPER_DIR` so `xcrun simctl` works
- Homebrew `openjdk`
- Homebrew `android-commandlinetools`
- Homebrew `android-platform-tools`
- Android SDK packages installed under `/opt/homebrew/share/android-commandlinetools`:
  - `emulator`
  - `platforms;android-36`
  - `system-images;android-36;google_apis;arm64-v8a`

Expected shell env:

```bash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="/opt/homebrew/opt/openjdk/bin:$ANDROID_HOME/cmdline-tools/latest/bin:/opt/homebrew/Caskroom/android-platform-tools/37.0.0/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

## Test on iOS

The iOS path was verified on the `iPhone 17` simulator through Expo Go. The detailed runbook lives in [SETUP.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/SETUP.md).

```bash
cd mobile
source ~/.zshrc
npx expo start --ios
```

Useful simulator commands:

```bash
xcrun simctl list runtimes
xcrun simctl list devices available
xcrun simctl list devices booted
```

If `expo start --ios` says Xcode is not fully installed even though Xcode.app exists, the shell is probably still pointing at the command line tools path. Use:

```bash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
```

## EAS and TestFlight

This repo now includes `eas.json` with these profiles:

- `development`
  - internal development client
- `simulator`
  - iOS simulator build
- `preview`
  - internal distribution build
- `production`
  - App Store / TestFlight build path

Before using EAS on a new machine:

```bash
cd mobile
npx eas-cli login
```

Check the active Expo account:

```bash
npx eas-cli whoami
```

Build a simulator artifact:

```bash
npx eas-cli build --platform ios --profile simulator
```

Build an internal iOS test artifact:

```bash
npx eas-cli build --platform ios --profile preview
```

Build the TestFlight / App Store artifact:

```bash
npx eas-cli build --platform ios --profile production
```

Submit the latest production build to App Store Connect:

```bash
npx eas-cli submit --platform ios --latest
```

Current blocker on this machine:

- `eas-cli` is installed and the repo is configured, but Expo account login has not been completed yet
- actual TestFlight build and submission still require:
  - Expo login
  - Apple Developer / App Store Connect access
  - signing credential setup during the first EAS iOS build

## Test on Android

The Android SDK and AVD were created on this machine with the following target:

- AVD name: `MuslimAI_Pixel_8`
- Device: `Pixel 8`
- System image: `system-images;android-36;google_apis;arm64-v8a`

Create the AVD again if needed:

```bash
echo no | avdmanager create avd \
  -n MuslimAI_Pixel_8 \
  -k "system-images;android-36;google_apis;arm64-v8a" \
  -d pixel_8
```

Boot the emulator:

```bash
source ~/.zshrc
emulator -avd MuslimAI_Pixel_8
```

Then, in another terminal:

```bash
cd mobile
source ~/.zshrc
npx expo start
```

Press `a` in the Expo terminal.

Useful Android checks:

```bash
adb devices -l
emulator -list-avds
sdkmanager --list_installed
```

## Current status

- `npm run typecheck` passes
- `npx expo config --json` resolves successfully
- iOS launch was verified on the `iPhone 17` simulator
- Android launch was verified on the `MuslimAI_Pixel_8` emulator
- `eas.json` exists and is ready for EAS build profiles
- the Stitch-based redesign is the active mobile UI
- setup details are documented in [SETUP.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile/SETUP.md)

## Next passes that still need work

- Move hard-coded translation and reciter lists into a cached remote config fetch
- Add persistent background audio controls for Quran and radio
- Add bookmarks / last-read position
- Add offline caching for surahs, azkar, and hadith
- Split the shared API layer into domain-specific hooks
- Add device-specific polish for Android back behavior and iOS audio session handling
- Phase 2: add mobile smart-speaker discovery and casting for adhan playback
- Phase 2 details:
  - discover user-approved speakers on the local network instead of broadcasting blindly
  - support selected target devices or saved speaker groups
  - evaluate Cast and DLNA support with native modules and a development build
  - document platform and store-policy constraints before implementation
  - tracked in GitHub issue `#7`
