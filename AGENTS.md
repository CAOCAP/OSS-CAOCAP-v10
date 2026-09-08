# Repository guidance

## Project context

CAOCAP is a platform where people discover, build, and publish AI agents together. Its core experiences are Explore, Build, and Collaborate.

Read `README.md`, `docs/product-vision.md`, and the relevant sections of `docs/SRS.md` before implementing product behavior. Requirements describe planned capabilities and should not be treated as evidence of implemented functionality.

For iOS setup and service configuration, see `apps/ios/README.md`. For the macOS shell, see `apps/macos/README.md`. For the Android, Windows, and Linux Hello World shells, see `apps/android/README.md`, `apps/windows/README.md`, and `apps/linux/README.md`.

## Structure and conventions

- `apps/ios/` and `apps/macos/` contain independent SwiftUI Xcode projects. Keep their internal `caocap/` paths intact when moving project folders.
- `apps/android/`, `apps/windows/`, and `apps/linux/` contain independent Hello World clients (Kotlin + Jetpack Compose, C# WinUI 3, GTK 4 + Rust). They are not shared with the Apple apps and do not implement Explore, Build, or Collaborate.
- `apps/web/` remains a web-client placeholder. `websites/landing/` contains a hosted waitlist prototype backed by Firebase; its visual stack is not a production web-app decision.
- Use lowercase names for new organizational directories. Preserve imported filenames and Xcode resource names.
- Keep app images, colors, and icons in the existing `Assets.xcassets` catalogs. Keep audio, localization, and other app resources in their existing resource folders. Shared brand artwork belongs in `assets/brand/`; research belongs in `docs/research/`.
- Consult the brand asset manifest (`assets/brand/cdl-v2/MANIFEST.md`) and research index (`docs/research/README.md`) before reusing imported material. Preserve source attribution and license notices in imported files.
- Update README links and documented paths when moving files. Keep planned and implemented functionality distinct in documentation.
- Follow the existing Swift and SwiftUI style. Add dependencies and shared abstractions only when a concrete feature needs them.

## Validation

Run commands from the repository root. Apple app builds require full Xcode with SDKs supporting the projects' configured deployment targets; Command Line Tools alone are insufficient.

If the active developer directory points to Command Line Tools, prefix Xcode commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
# iOS simulator build without device signing
xcodebuild -project apps/ios/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/caocap-ios-build CODE_SIGNING_ALLOWED=NO build

# macOS build without signing
xcodebuild -project apps/macos/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/caocap-macos-build CODE_SIGNING_ALLOWED=NO build

# Android debug APK (requires JDK 17 and ANDROID_HOME / an SDK)
./apps/android/caocap/gradlew -p apps/android/caocap :app:assembleDebug

# Backend: unit tests, then rules and integration tests against the emulator
npm --prefix firebase/functions test
firebase emulators:exec --config firebase/firebase.json --project demo-caocap --only firestore "npm --prefix firebase/functions run test:rules"

git diff --check
```

### Signed macOS builds

`CODE_SIGNING_ALLOWED=NO` skips entitlement processing, so an unsigned build
embeds no entitlements at all. Sandbox and helper mistakes are invisible to it:
the build succeeds and the tests pass either way. Anything touching
entitlements, the XPC helper, or the bundled driver must also be checked on a
signed build.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apps/macos/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/caocap-signed CODE_SIGN_IDENTITY="Apple Development" CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=6QYT6GJB4Z build

./scripts/release/verify-macos-bundle.sh /tmp/caocap-signed/Build/Products/Debug/caocap.app
```

That script asserts the invariants the architecture depends on: the app is
sandboxed, the helper is not, and the driver is bundled where the helper looks
for it and signed the same way. Pass the generic `"Apple Development"` identity
rather than a full identity string, or the SwiftPM dependencies fail with
conflicting provisioning settings.

Windows builds need Visual Studio 2022 and the Windows App SDK on Windows; they are not part of the Apple validation path. Linux builds need GTK 4 / libadwaita on Linux, or Flatpak with the GNOME SDK as described in `apps/linux/README.md`; they are not required on macOS.

The iOS project includes `caocapTests` and `caocapUITests`. macOS has a `caocapTests` target covering saved-file verification, reporting-failure ordering, and run reservation under cancellation. The relay's own decision logic (busy, expired, setup incomplete, no folder, opt-out) is still inlined in `RemoteCommandRelay` and is not yet covered. For macOS UI changes, run the app on **My Mac** and check wake/tuck, CoCaptain/CoStar switch, drag, tap-to-toggle Agent chat, prompt entry and draft retention, and that the chat's Open CAOCAP button focuses the existing hub window. See `apps/macos/README.md` for the chat checks.

- For app changes, build the affected platform, run relevant tests, and check the changed flow when a simulator or device is available.
- For documentation and folder moves, verify links, project-relative paths, and asset references.
- Report validation results and any limitations accurately.
