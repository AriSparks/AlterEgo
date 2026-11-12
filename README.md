# AlterEgo

AlterEgo is a native SwiftUI app for iOS and macOS that helps plural systems track who is fronting at any given time. Create alters with a name, emoji or photo, and a color, mark them as fully or partially fronting, and review your fronting history on an interactive timeline — all from the app or a home-screen widget.

## Features

- **Alters** — create, edit, and delete alters with a name, emoji or photo avatar, role, pronouns, description, characteristics, and banner colors.
- **Fronting** — start and stop fronting sessions, with two modes:
  - **Fully fronting** — one alter takes over and everyone else's session ends.
  - **Partially fronting** — an alter fronts alongside whoever is already fronting.
- **Session editing** — adjust session start and end times, notes, and fronting mode, or remove a session entirely.
- **Timeline** — a day-by-day history of sessions, with an interactive per-day view, a time scrubber, and a live "now" indicator.
- **Home-screen widget** — small, medium, and large widgets show who is currently fronting, their avatar, the current fronting count, and the active theme.
- **Appearance** — light, dark, system, or scheduled Daytime mode; accent colors; custom light and dark palettes with solid or gradient fills; optional partial-fronting stripes; 24-hour time and week-start preferences.
- **Backup and restore** — export all alters and sessions, including images, to a JSON backup and import it with merge or replace options.
- **Optional iCloud sync** — key-value sync for text data, compiled out by default for free-account builds.
- **App Intents** — "Front Alongside", "Take Over", and "Stop Fronting" actions are available from the widget and system automation.
- **Shared state** — data is persisted to a shared App Group so the app and widget can stay in sync.

## Requirements

- Xcode with the iOS and macOS SDKs
- Deployment targets: iOS 27.0 and macOS 27.0
- Swift 5.0

The default build does not require iCloud and is intended to work with a free Apple developer account. App Groups, live widget data sharing, and iCloud sync require a paid Apple Developer Program account; see [Data storage](#data-storage).

## Project structure

```
AlterEgo/              Main app target
AlterEgoWidget/        WidgetKit extension (home-screen widget + App Intents)
Shared/                Shared models, storage, and UI helpers used by both targets
App Icon/              App icon sources
Build Apps.sh          Script to build the iOS IPA and macOS app
```

Key shared files:

- `Shared/Models.swift` — `Alter`, `FrontingSession`, `AppState`, the `FrontingEngine`, and JSON-backed `SharedStorage`.
- `Shared/AvatarView.swift` — the avatar, status-badge, and fronting-bar views plus color/image helpers.

## Building and running

1. Open `AlterEgo.xcodeproj` in Xcode.
2. Select the `AlterEgo` scheme and a destination (a simulator or device for iOS, or your Mac for macOS).
3. Build and run (`⌘R`).

The app and widget communicate through an App Group. If you change the bundle identifier or team, update the App Group ID in `Shared/Models.swift` (`SharedConstants.appGroupID`) and in both entitlements files.

## Building app bundles

`Build Apps.sh` archives and packages both platforms. Run it from the project root:

```sh
./Build Apps.sh
```

Outputs:

- `build/ios/AlterEgo.ipa`
- `build/macos/AlterEgo.app`
- `build/macos/AlterEgo.zip`

Build only one platform or change the configuration:

```sh
./Build Apps.sh --ios
./Build Apps.sh --macos
./Build Apps.sh --debug
```

The script uses automatic signing and passes `-allowProvisioningUpdates` by default. Set `ALLOW_PROVISIONING_UPDATES=0` to disable that, or use `CODE_SIGNING_ALLOWED=NO` for an unsigned build:

```sh
CODE_SIGNING_ALLOWED=NO ./Build Apps.sh
```

The signed IPA packages the archived iOS `.app` directly in a `Payload` folder. The macOS build also creates a zip for distribution.

## Widget and URL scheme

The widget exposes a quick action that deep-links into the app using the `alterego://add-fronter` URL. Tapping it opens the app and presents the "Add Fronter" sheet.

## Data storage

State is stored as JSON (`alterego-state.json`) inside the App Group container, with a `UserDefaults` fallback when the container is unavailable. The widget reloads its timeline whenever the app writes a change.

The app and widget share data through an App Group (`group.gay.arisparks.AlterEgo`). That ID is defined in `Shared/Models.swift` and must match the value in both entitlements files. Note that App Groups require a paid Apple Developer Program account — when sideloaded with a free Apple ID (e.g., SideStore/iLoader/AltStore), the shared container is unavailable and the widget cannot read live fronting state.

## Backups

Open **Settings → Export & Import** to create a JSON backup containing every alter, session, and image. Importing a backup lets you merge it with current data or replace all current data. Backups also work in builds that do not use iCloud.

## Optional iCloud sync

iCloud sync is disabled at compile time by default. The default build stores data locally and shows an explanatory message in **Settings → iCloud Sync**.

To enable it:

1. Use a paid Apple Developer Program account and enable iCloud Key-value storage for the app's bundle identifier in the Apple Developer portal.
2. Add the iCloud capability to the `AlterEgo` target and add the `com.apple.developer.ubiquity-kvstore-identifier` entitlement. The widget does not need cloud-sync access.
3. Add `CLOUD_SYNC` to the target's **Swift Active Compilation Conditions** for the configurations you build.
4. Rebuild, then enable **Settings → iCloud Sync**.

Sync uses `NSUbiquitousKeyValueStore` and is best for text data. Apple limits key-value storage to roughly 900 KB, so large image collections may exceed the limit. Use **Export & Import** for complete backups.
