# Muslim AI Mobile

This directory contains the native mobile client for `Muslim_AI`, built with Expo and React Native so the same codebase can target Android and iOS.

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
- Homebrew `openjdk@21`
- Homebrew `android-commandlinetools`
- Homebrew `android-platform-tools`
- Android SDK packages installed under `/opt/homebrew/share/android-commandlinetools`:
  - `emulator`
  - `platform-tools`
  - `platforms;android-35`
  - `system-images;android-35;google_apis;arm64-v8a`

Expected shell env:

```bash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"
```

## Test on iOS

The iOS path was verified with Expo Go on the `iPhone 17` simulator.

```bash
cd mobile
npm install
npm run ios
```

If Expo Go opens a one-time runtime information sheet, tap `Continue`.

Useful simulator commands:

```bash
xcrun simctl list devices | rg "iPhone 17|Booted"
xcrun simctl boot "iPhone 17"
xcrun simctl bootstatus "iPhone 17" -b
```

## Test on Android

The Android SDK and AVD were created on this machine with the following target:

- AVD name: `MuslimAI_Pixel_8`
- Device: `Pixel 8`
- System image: `system-images;android-35;google_apis;arm64-v8a`

Create the AVD again if needed:

```bash
echo no | avdmanager create avd \
  -n MuslimAI_Pixel_8 \
  -k "system-images;android-35;google_apis;arm64-v8a" \
  -d pixel_8
```

Boot the emulator:

```bash
emulator @MuslimAI_Pixel_8 -netdelay none -netspeed full
```

Then, in another terminal:

```bash
cd mobile
npm install
npm run android
```

Useful Android checks:

```bash
adb devices -l
emulator -list-avds
sdkmanager --list_installed
```

If Android does not attach on first boot, wait for the emulator to finish cold booting, then rerun `npm run android`.

## Current status

- `npm run typecheck` passes
- `npx expo-doctor` passes
- iOS launch was verified in Expo Go
- Audio was migrated to `expo-audio` for Expo SDK 55 compatibility
- Prayer reminders now support:
  - local notification scheduling for selected prayers
  - persisted prayer reminder settings
  - local-device adhan playback while the app is open
- Android host tooling is installed and the AVD exists, but first-boot validation still needs one clean `adb`/Expo attach cycle

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
