# Mobile Roadmap

This note captures the mobile prayer-automation roadmap after Phase 1 local-device support was implemented.

## Current Gap

The mobile app currently supports:

- prayer time lookup
- qibla lookup
- current-location based prayer calculations
- Quran playback
- library and radio integrations

The mobile app now supports:

- scheduled local prayer reminders
- user-selected prayer automation
- local-device adhan playback while the app is open

The mobile app does not currently support:

- smart-speaker discovery or casting
- local-network speaker broadcasting

That is different from the web app, where prayer automation and speaker targeting already exist in `Prayer_Time`.

## Phase 1

Status: implemented

### Goal

Add prayer-time reminders and local adhan playback to the mobile app.

### Scope

- schedule local notifications for prayer times based on the selected location
- allow the user to enable or disable automatic adhan per prayer
- play the adhan on the phone or tablet itself while the app is open
- keep the feature explicitly local to the device

### Non-goals

- no local-network scanning
- no smart-speaker discovery
- no automatic whole-network broadcasting

### Engineering Notes

- This is implemented around mobile-native scheduling and notification behavior, not around the web automation loop.
- iOS and Android have different background execution rules, so the current implementation keeps local adhan playback to foreground app runtime and uses local notifications for background delivery.
- The UI makes it clear that Phase 1 plays on the mobile device speakers only.

### Acceptance Criteria

- user can enable prayer reminders from the mobile app
- user can select which prayers should trigger adhan playback
- prayer notifications are scheduled according to the active location-based schedule
- adhan plays locally on the device while the app is open
- the app documents the local-device-only limitation clearly

## Phase 2

Status: open

Tracking issue: `#7` on GitHub

### Goal

Add optional smart-speaker targeting from the mobile app.

### Scope

- discover supported speaker targets on the local network
- let the user select approved speakers instead of broadcasting blindly
- support saved speaker groups if the implementation is stable enough
- align device-targeting concepts with the existing web prayer automation model

### Non-goals

- no silent automatic broadcast to every device found on the network
- no implementation that depends on Expo Go alone if native modules are required

### Engineering Notes

- This is a larger task than Phase 1 and likely requires native-capability decisions.
- Cast and DLNA support should be treated as separate integration tracks with different technical risks.
- Network discovery, mDNS or SSDP behavior, and platform permissions need to be validated on real devices, not only simulators.
- This phase should start only after Phase 1 is stable.

### Acceptance Criteria

- user can discover supported speakers from the mobile app
- user can choose target speakers explicitly
- adhan routing can send to chosen speakers only
- failure handling is explicit when devices are unreachable or unsupported
- the implementation is documented for both iOS and Android constraints
