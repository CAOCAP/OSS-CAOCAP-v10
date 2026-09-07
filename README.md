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
| Android | Directory scaffold only |
| Windows | Directory scaffold only |
| Linux | Directory scaffold only |
| Landing page | Hosted waitlist in [`websites/landing/`](websites/landing/); emails stored in Firestore via `joinWaitlist`. Vite prototype, not the planned web app |
| Web application | Directory scaffold only |

## Repository structure

```text
.
├── apps/
│   ├── ios/                 # iOS SwiftUI project and app assets
│   ├── macos/               # macOS SwiftUI project and setup notes
│   ├── android/             # Planned Android client
│   ├── windows/             # Planned Windows client
│   ├── linux/               # Planned Linux client
│   └── web/                 # Planned web client
├── websites/
│   └── landing/             # Hosted waitlist (Vite prototype on Firebase Hosting)
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

The runnable applications currently require macOS and an Xcode version compatible with the projects' configured SDKs.

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

### Landing waitlist

The waitlist page lives in [`websites/landing/`](websites/landing/). Run `npm install && npm run dev` there. Submitting an address calls `joinWaitlist` and stores it in Firestore. Deploy with `npm run build` in that folder, then `firebase deploy --only functions,hosting` from [`firebase/`](firebase/).

## Technology

Technology currently present in the repository:

- Swift
- SwiftUI
- Xcode projects for iOS and macOS
- A Vite + React + Tailwind waitlist prototype under `websites/landing/`, hosted on Firebase (not a production stack decision for the web app)

Technology choices for the other clients and shared services have not been made.

## Documentation

- [Product vision](docs/product-vision.md) explains why CAOCAP exists and the experience it intends to create.
- [Software Requirements Specification](docs/SRS.md) defines the envisioned system requirements and records unresolved decisions.
- [Brand assets](assets/brand/) contains artwork, mascot references, and icon variants.
- [Research index](docs/research/README.md) links to the imported UX reports and audits.
- [iOS Home redesign plan](docs/ios-home-redesign-plan.md) records agreed navigation, implementation steps, and open decisions.
- [iOS setup](apps/ios/README.md) describes Firebase and package configuration for the iOS app.
- [macOS setup](apps/macos/README.md) describes the current Mac shell and how to run it.
- [macOS Agent plan](docs/macos-agent-plan.md) covers chat UX, real AI conversation, and the first computer-use task.
- [macOS companion play](docs/macos-companion-play-plan.md) describes the floating Agent's local character toys.
- [Agent guidance](AGENTS.md) describes repository conventions and validation commands.

## Roadmap

The roadmap focuses on three core experiences: Explore, Build, and Collaborate. Planned capabilities include discovering and trying agents, creating and testing agents, collaborating on shared projects, and publishing agents for others to use. These capabilities are not yet implemented.

Development will start with iOS and macOS, followed by the other platforms.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
