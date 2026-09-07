# CAOCAP

**Explore. Build. Collaborate.**

CAOCAP is a platform where people discover, build, and publish AI agents together.

Users will be able to explore agents built by the community, create their own, and collaborate on shared projects. To build agents, they will use mindmaps to organize context and knowledge, and flowcharts to define logic and conditional flows. They can test and improve agents together, then publish them for others to use. The building experience will feel playful and responsive.

> Explore agents → build or join a project → collaborate and test → publish → improve together

## Project status

CAOCAP is transitioning to a collaborative AI agent platform. Agent discovery, building, collaboration, and publishing are planned and not yet implemented.

| Area | Status |
| --- | --- |
| iOS | Agent-library Home, separate default-agent Workspaces and chat, Profile / Settings; Explore, Communities, and creation wizard placeholders; service configuration required |
| macOS | SwiftUI shell with app icon, menu-bar status item, and a floating Agent with its own chat UI; AI responses, computer use, Explore, Build, and Collaborate are not implemented |
| Android | Kotlin + Jetpack Compose Hello World shell; Explore, Build, and Collaborate are not implemented |
| Windows | C# WinUI 3 Hello World shell; Explore, Build, Collaborate, and computer use are not implemented |
| Linux | GTK 4 + Rust (gtk4-rs / libadwaita) Hello World shell; Explore, Build, Collaborate, and computer use are not implemented |
| Landing page | Throwaway waitlist UI prototype in [`websites/landing/`](websites/landing/); not a shipped site |
| Web application | Directory scaffold only |

## Repository structure

```text
.
├── apps/
│   ├── ios/                 # iOS SwiftUI project and app assets
│   ├── macos/               # macOS SwiftUI project and setup notes
│   ├── android/             # Android Compose Hello World shell
│   ├── windows/             # Windows WinUI 3 Hello World shell
│   ├── linux/               # Linux GTK 4 + Rust Hello World shell
│   └── web/                 # Planned web client
├── websites/
│   └── landing/             # Throwaway waitlist UI prototype; not a shipped site
├── assets/
│   └── brand/               # Imported artwork and icon variants
├── docs/
│   ├── research/            # Imported UX research and audits
│   ├── product-vision.md
│   └── SRS.md
├── AGENTS.md                # Repository guidance for coding agents
├── README.md
└── .gitignore
```

## Getting started

Apple apps require macOS and an Xcode version compatible with the projects' configured SDKs. The Android shell can build with the Android SDK. The Windows and Linux shells need those operating systems (or Flatpak on Linux).

### iOS

1. Open [the iOS project](apps/ios/caocap/caocap.xcodeproj) in Xcode.
2. Follow the [iOS setup notes](apps/ios/README.md), including Firebase configuration and package resolution.
3. Select the `caocap` scheme and an iOS 26 or later simulator or compatible device.
4. Run the project with **Product → Run** or `Command-R`.

### macOS

1. Open [the macOS project](apps/macos/caocap/caocap.xcodeproj) in Xcode.
2. Follow the [macOS setup notes](apps/macos/README.md), including a local copy of the iOS `GoogleService-Info.plist`.
3. Select the `caocap` scheme and the **My Mac** destination.
4. Run the project with **Product → Run** or `Command-R`.

You should see the CAOCAP window, a cube status item in the menu bar, and CoCaptain on the desktop. Tap CoCaptain to open its compact chat UI. The floating Agent has local play (faces, bob, peek, spin) that is not an AI connection. Prompts stay in memory for the current session; agent responses and computer use are not connected. The hub window still shows placeholder Hello World content.

### Android

1. Follow the [Android setup notes](apps/android/README.md).
2. Open [the Android Gradle project](apps/android/caocap/) in Android Studio, or run `./apps/android/caocap/gradlew -p apps/android/caocap :app:assembleDebug` from the repository root.

You should see a **CAOCAP** activity that shows Hello World. Explore, Build, and Collaborate are not implemented.

### Windows

1. On Windows, follow the [Windows setup notes](apps/windows/README.md).
2. Open [the WinUI 3 solution](apps/windows/caocap/caocap.sln) in Visual Studio 2022.

This does not build on macOS. GitHub Actions on `windows-latest` compiles the Debug|x64 shell; local run still needs Visual Studio 2022. You should see a **CAOCAP** window that shows Hello World. The floating Agent and computer use are not implemented.

### Linux

1. Follow the [Linux setup notes](apps/linux/README.md). Prefer Flatpak with the GNOME 48 SDK.
2. From [apps/linux/caocap/](apps/linux/caocap/), build with `flatpak-builder` or `cargo run` if host GTK 4 and libadwaita devel packages are new enough.

You should see a **CAOCAP** window that shows Hello World. The floating Agent and computer use are not implemented.

### Landing page prototype

A local waitlist UI prototype lives in [`websites/landing/`](websites/landing/). Run `npm install && npm run dev` there. It is not a production site and does not collect email.

## Technology

Technology currently present in the repository:

- Swift and SwiftUI (iOS and macOS Xcode projects)
- Kotlin and Jetpack Compose (Android Hello World shell)
- C# WinUI 3 / Windows App SDK (Windows Hello World shell)
- Rust gtk4-rs and libadwaita (Linux Hello World shell)
- A throwaway Vite + React + Tailwind waitlist prototype under `websites/landing/` (not a production stack decision)

Shared services and the web client stack have not been selected. These Hello World shells do not implement Explore, Build, or Collaborate.

## Documentation

- [Product vision](docs/product-vision.md) explains why CAOCAP exists and the experience it intends to create.
- [Software Requirements Specification](docs/SRS.md) defines the envisioned system requirements and records unresolved decisions.
- [Brand assets](assets/brand/) contains artwork, mascot references, and icon variants.
- [Research index](docs/research/README.md) links to the imported UX reports and audits.
- [iOS Home redesign plan](docs/ios-home-redesign-plan.md) records agreed navigation, implementation steps, and open decisions.
- [iOS setup](apps/ios/README.md) describes Firebase and package configuration for the iOS app.
- [macOS setup](apps/macos/README.md) describes the current Mac shell and how to run it.
- [Android setup](apps/android/README.md) describes the Compose Hello World shell.
- [Windows setup](apps/windows/README.md) describes the WinUI 3 Hello World shell.
- [Linux setup](apps/linux/README.md) describes the GTK 4 + Rust Hello World shell and the Flatpak/GNOME SDK build.
- [macOS Agent plan](docs/macos-agent-plan.md) covers chat UX, real AI conversation, and the first computer-use task.
- [macOS companion play](docs/macos-companion-play-plan.md) describes the floating Agent's local character toys.
- [Agent guidance](AGENTS.md) describes repository conventions and validation commands.

## Roadmap

The roadmap focuses on three core experiences: Explore, Build, and Collaborate. Planned capabilities include discovering and trying agents, creating and testing agents, collaborating on shared projects, and publishing agents for others to use. These capabilities are not yet implemented.

Development will start with iOS and macOS, followed by the other platforms.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
