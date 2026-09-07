# CAOCAP for iOS

SwiftUI shell targeting iOS 26 or later. Requires full Xcode with a compatible iOS SDK.

The app now opens to an agent library with three native bottom tabs on both iPhone and iPad: **Explore, Home, Communities**. This is the first foundation of the [Home redesign plan](../../docs/ios-home-redesign-plan.md).

- **Home** shows an avatar/name grid with CoCaptain and CoStar included by default. Card menus remove agents from Home, with Undo for the latest removal. Library membership persists locally; removing both defaults shows Create and Explore actions.
- **Workspace** opens full-screen for the selected agent with a native glass back button floating over the canvas, without a top navigation bar or bottom tabs. Each default agent has a separate saved canvas and local chat history. The existing card canvas is the temporary surface; mind map and flowchart design and behavior remain TBD.
- **Agent FAB** appears only in a Workspace. Tap or ⌘J opens large chat (or closes a listed sheet); long-press retains Chat / Voice / Video. Chat drafts stay with each agent during the app session. Returning Home stops streaming and ends an active call.
- **Profile → Settings** is reachable through the avatar in Home's top-right corner.
- **Create agent** opens a dismissible setup destination. Wizard steps and actual creation are not implemented.
- **Explore and Communities** are placeholder destinations. Discovery, acquisition, membership, and shared building are not connected.
- **Sign-in** uses Firebase Auth (anonymous first, then Apple / Google / GitHub). **CAOCAP Pro** remains available through Profile / Settings and usage limits.
- **Devices** in Profile lists other signed-in installs on the same provider-linked account (for example a Mac). Guest sessions do not publish a heartbeat. **Open YouTube on Mac** asks a Cloud Function to create an allowlisted command; an opted-in Mac opens `https://www.youtube.com`. In **Agent** mode, CoCaptain can send that homepage command, or send `createOpenURL` with an allowlisted documentation URL (developer.apple.com / docs.swift.org / swift.org) so the Mac opens a SwiftUI tutorial page (Ask / Plan cannot).

Removal changes Home membership only; it does not delete canvas or conversation files. Cloud library sync is not implemented.

## Setup

1. Open [caocap.xcodeproj](caocap/caocap.xcodeproj) and let Xcode resolve its Swift packages.
2. Register one Apple app in your Firebase project using the shared bundle identifier `com.Ficruty.caocap`. Add its `GoogleService-Info.plist` to the iOS `caocap` target at [caocap/Resources/Config/GoogleService-Info.plist](caocap/caocap/Resources/Config/GoogleService-Info.plist). Copy the same plist into the [macOS app](../macos/README.md). Do not register a second Firebase Apple app for Mac.
3. Deploy Firestore rules and the `createOpenYouTube` / `createOpenYouTubeVideo` / `createOpenURL` functions from [firebase/](../../firebase/) with `firebase deploy --only functions,firestore:rules`. The project must be on the **Blaze** plan. Until that deploy succeeds, device listing and Open YouTube on Mac will fail.
4. For Google sign-in, enable the Google provider in Firebase Authentication and replace the Google URL scheme in [Info.plist](caocap/caocap/Resources/Config/Info.plist) with your configuration's `REVERSED_CLIENT_ID`.
5. Select the `caocap` scheme and an iOS 26 or later simulator. For a physical device, configure your development team under **Signing & Capabilities**.
6. Run with **Product → Run** or `Command-R`.

Firebase configuration is required at launch. CoCaptain cloud chat also needs the project's Firebase AI / Gemini setup. Individual features may require additional service setup.

## What you should see

On a fresh install, intro and persona pick come first, followed by Home with both default agents. Open either agent to use the existing canvas and its chat. Return to Home using the top-left back button. Changing agents switches the canvas, chat history, draft, avatar, and chat title.

The Home journey UI test covers the tabs, wizard dismissal, Profile → Settings, separate agent drafts, removal, and empty-state persistence. Run it on a development simulator; it changes that simulator's local agent library.

## Related notes

- [Canvas](caocap/caocap/Features/Canvas/README.md)
- [CoCaptain](caocap/caocap/Features/CoCaptain/README.md)
- [App session](caocap/caocap/Services/AppSession/README.md)
- [Auth](caocap/caocap/Features/Auth/README.md)
- [Subscription](caocap/caocap/Features/Subscription/README.md)
