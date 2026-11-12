# AlterEgo

AlterEgo is a native SwiftUI app for iOS and macOS that helps plural systems track who is fronting at any given time. Create alters with a name, emoji or photo, and a color, mark them as fully or partially fronting, and review your fronting history on an interactive timeline — all from the app or a home-screen widget.

## Features

- **Alters** — create, edit, and delete alters. Each one gets a name, an emoji or photo avatar, and a color.
- **Fronting** — start and stop fronting sessions, with two modes:
  - **Fully fronting** — one alter takes over and everyone else's session ends.
  - **Partially fronting** — an alter fronts alongside whoever is already fronting.
- **Timeline** — a day-by-day history of sessions, with an interactive per-day view, a time scrubber, and a live "now" indicator.
- **Home-screen widget** — small, medium, and large widgets show who is currently fronting and offer quick actions.
- **App Intents** — "Front Alongside", "Take Over", and "Stop Fronting" actions are available from the widget and system automation.
- **Shared state** — data is persisted to a shared App Group so the app and widget stay in sync.

## Requirements

- Xcode with the iOS and macOS SDKs
- Deployment targets: iOS 27.0 and macOS 27.0
- Swift 5.0

## Project structure

```
AlterEgo/              Main app target
AlterEgoWidget/        WidgetKit extension (home-screen widget + App Intents)
Shared/                Shared models, storage, and UI helpers used by both targets
App Icon/              App icon sources
Build IPA.sh           Script to package a build into an .ipa
```

Key shared files:

- `Shared/Models.swift` — `Alter`, `FrontingSession`, `AppState`, the `FrontingEngine`, and JSON-backed `SharedStorage`.
- `Shared/AvatarView.swift` — the avatar and status-badge views plus a hex-color helper.

## Building and running

1. Open `AlterEgo.xcodeproj` in Xcode.
2. Select the `AlterEgo` scheme and a destination (a simulator or device for iOS, or your Mac for macOS).
3. Build and run (`⌘R`).

The app and widget communicate through an App Group. If you change the bundle identifier or team, update the App Group ID in `Shared/Models.swift` (`SharedConstants.appGroupID`) and in both entitlements files.

## Building an IPA


1. From the project root, build with `xcodebuild build -project AlterEgo.xcodeproj -scheme AlterEgo -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic`
2. Again from the project root, archive the app with `xcodebuild archive -project AlterEgo.xcodeproj -scheme AlterEgo -configuration Release -sdk iphoneos -archivePath build/AlterEgo.xcarchive -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic`
3. Run `./Build IPA.sh` to package the built `.app` into an `AlterEgo.ipa` in `build/ipa/`.

## Widget and URL scheme

The widget exposes a quick action that deep-links into the app using the `alterego://add-fronter` URL. Tapping it opens the app and presents the "Add Fronter" sheet.

## Data storage

State is stored as JSON (`alterego-state.json`) inside the App Group container, with a `UserDefaults` fallback when the container is unavailable. The widget reloads its timeline whenever the app writes a change.

The app and widget share data through an App Group (`group.gay.arisparks.AlterEgo`). That ID is defined in `Shared/Models.swift` and must match the value in both entitlements files. Note that App Groups require a paid Apple Developer Program account — when sideloaded with a free Apple ID (e.g., SideStore/iLoader/AltStore), the shared container is unavailable and the widget cannot read live fronting state.
