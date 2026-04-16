# Mobile Setup Guide

This document captures the working local setup for the Expo mobile app under [mobile](/Users/mkhairy/Documents/GitHub/Muslim_AI/mobile).

Use this file first on a new machine when you need to run the app on:

- iPhone simulator
- Android emulator
- physical iPhone with Expo Go
- physical Android device with Expo Go

## App location

```bash
cd /Users/mkhairy/Documents/GitHub/Muslim_AI/mobile
```

## Current stack

- Expo SDK `55`
- React Native `0.82`
- iOS simulator verified through Xcode `26.4`
- Android emulator verified through Android SDK Platform `36`

## Required shell environment

The shell profile on this machine now includes:

```bash
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

export JAVA_HOME="/opt/homebrew/opt/openjdk"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="/opt/homebrew/opt/openjdk/bin:$ANDROID_HOME/cmdline-tools/latest/bin:/opt/homebrew/Caskroom/android-platform-tools/37.0.0/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

Reload the shell before testing:

```bash
source ~/.zshrc
```

## Install app dependencies

```bash
npm install
```

## Start Metro

```bash
npx expo start
```

From the Expo terminal:

- press `i` to open iOS simulator
- press `a` to open Android emulator
- or scan the QR code with Expo Go on a phone

## iOS simulator

### Verified status on this machine

- Xcode path is resolved through `DEVELOPER_DIR`
- `xcrun simctl` works
- iOS runtime installed:
  - `iOS 26.4`
- verified simulator target:
  - `iPhone 17`

### Useful commands

Check runtimes:

```bash
source ~/.zshrc
xcrun simctl list runtimes
```

Check available devices:

```bash
source ~/.zshrc
xcrun simctl list devices available
```

Check booted simulator:

```bash
source ~/.zshrc
xcrun simctl list devices booted
```

Open the app in iOS simulator:

```bash
cd /Users/mkhairy/Documents/GitHub/Muslim_AI/mobile
source ~/.zshrc
npx expo start --ios
```

### Notes

- If `simctl` says it cannot find the utility, the shell is not using full Xcode.
- If Simulator opens but Expo does not attach, start Metro first and then press `i`.

## Android emulator

### Verified status on this machine

- Java installed through Homebrew `openjdk`
- Android command-line tools installed
- `adb` works
- installed Android packages:
  - `emulator`
  - `platforms;android-36`
  - `system-images;android-36;google_apis;arm64-v8a`
- verified AVD:
  - `MuslimAI_Pixel_8`

### Useful commands

Check installed SDK packages:

```bash
source ~/.zshrc
sdkmanager --list_installed
```

List AVDs:

```bash
source ~/.zshrc
avdmanager list avd
```

Boot the verified emulator:

```bash
source ~/.zshrc
emulator -avd MuslimAI_Pixel_8
```

Check attached Android devices:

```bash
source ~/.zshrc
adb devices -l
```

Open the app in Android emulator:

```bash
cd /Users/mkhairy/Documents/GitHub/Muslim_AI/mobile
source ~/.zshrc
npx expo start
```

Then press `a` in the Expo terminal.

### Notes

- The emulator may need a few seconds before `adb devices -l` shows `device`.
- If Expo says it cannot find Android, verify `adb version` and `sdkmanager --version`.

## Physical device testing

### iPhone

1. Install `Expo Go` from the App Store.
2. Put the iPhone on the same Wi-Fi as this Mac.
3. Run:

```bash
cd /Users/mkhairy/Documents/GitHub/Muslim_AI/mobile
source ~/.zshrc
npx expo start
```

4. Scan the QR code from Expo Go.

### Android phone

1. Install `Expo Go` from Google Play.
2. Put the Android phone on the same Wi-Fi as this Mac.
3. Run:

```bash
cd /Users/mkhairy/Documents/GitHub/Muslim_AI/mobile
source ~/.zshrc
npx expo start
```

4. Scan the QR code from Expo Go.

## Validation commands

Type-check:

```bash
npm run typecheck
```

Check Expo config resolution:

```bash
npx expo config --json
```

## Current known state

- iOS simulator launch works
- Android emulator launch works
- Expo Metro serves both platforms from the same session
- The redesigned Stitch-based mobile UI is now the active mobile surface

## Recommended first steps on a new machine

1. Install Xcode and open it once.
2. Install Homebrew.
3. Install `openjdk`, `android-commandlinetools`, and `android-platform-tools`.
4. Add the shell exports shown above.
5. Install one Android system image and create one AVD.
6. Run `npm install`.
7. Run `npx expo start`.
