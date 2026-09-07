# CAOCAP for macOS

SwiftUI app targeting macOS 26.5 or later. Requires full Xcode with a compatible macOS SDK.

## Setup

1. Complete the [iOS Firebase setup](../ios/README.md): register one Apple app in Firebase with bundle ID `com.Ficruty.caocap`. Copy that `GoogleService-Info.plist` to [caocap/caocap/resources/GoogleService-Info.plist](caocap/caocap/resources/GoogleService-Info.plist). Do not register a second Firebase Apple app for Mac. If Firebase issues a new plist, replace both copies.
2. Enable Sign in with Apple on that same App ID (already used by iOS). Do not create a second App ID for Mac.
3. Open [caocap.xcodeproj](caocap/caocap.xcodeproj) in Xcode and let it resolve Swift packages.
4. Select the `caocap` scheme and the **My Mac** destination.
5. Run with **Product → Run** or `Command-R`.

## Source layout

The Mac target is an independent Xcode project. Its `caocap/` folder uses lowercase directories:

| Directory | Contents |
| --- | --- |
| `app/` | Process entry, menu bar scenes, Firebase bootstrap, Apple sign-in |
| `features/hub/` | CAOCAP window |
| `features/companion/` | Floating Agent, persona, and its chat |
| `services/` | Window focus and other non-UI helpers |
| `resources/` | `Assets.xcassets` and the local `GoogleService-Info.plist` copy |

## Product surfaces

**CAOCAP** is the agents hub for exploring, building, and collaborating on agents. The floating **Agent** is a separate desktop surface: tap it to open its own compact chat and enter prompts. **CoCaptain** is the platform-provided default agent. Computer-use execution is planned; this iteration implements the chat UI only.

The [macOS Agent plan](../../docs/macos-agent-plan.md) defines the next three phases: finish chat UX, connect real AI conversation, and complete one computer-use task.

## What is implemented

- Firebase initializes at launch from a local copy of the iOS `GoogleService-Info.plist`. The status menu can **Sign in with Apple** and show the Firebase UID. The session survives quit and relaunch. Anonymous sessions are rejected. Device linking and remote commands are not implemented.
- A single **CAOCAP** window (placeholder Hello World content).
- The CoCaptain porthole **app icon** and the cube-and-orbit **menu-bar** status item.
- A floating Agent above other apps. Drag to move; click to toggle its own chat beside it. The chat stays within the screen's visible bounds and follows the Agent after dragging. CoCaptain and CoStar share local play: mood faces, squash-and-bounce, idle "Hey!" / sleepy bubbles, a lean toward the nearby pointer, double-tap spin, a right-click Spin / Wave hello menu, and a one-time confetti burst the first time each persona opens chat. This is desktop character behavior, not an AI connection.
- A compact chat with persona artwork, prompt suggestions, a multiline composer, and a scrollable prompt history. Click the arrow or press **Return** or **Command-Return** to add a prompt; **Option-Return** inserts a new line. Blank prompts are ignored. Prompts are explicitly marked **Not sent** because no agent service is connected.
- Close chat with its close button, **Escape**, or another tap on the Agent. Drafts and prompt history remain separately for CoCaptain and CoStar until the app quits. They are not saved to disk or sent to a service.
- The **Agent** app menu and **Command-Shift-J** open chat from the keyboard. The same chat, visibility, and persona controls are available in the status menu.
- Open the existing hub window (or reopen it) with the chat's grid button or **Open CAOCAP** in the menu bar. The menu bar can also show/hide the Agent and switch between **CoCaptain** and **CoStar**. Hiding the Agent closes its chat.

Wake/tuck, persona, and companion position persist locally. Reduced Motion turns off the idle bob, squash, peek, spin, and confetti; mood and bubble still change instantly.

## What is not implemented

Explore, Build, and Collaborate are planned and not present on Mac. There is no canvas, live agent conversation, computer-use execution, device linking, or agent-driven companion status. The chat is a local UI preview, not a working AI connection.

To confirm the same account on both devices, sign in with Apple on Mac and with a provider-linked Apple account in iOS Profile (not anonymous). The Firebase UIDs should match.

The idle and mood sprites in `caocap/resources/Assets.xcassets` were knocked out from CDL avatar art for a transparent desktop pet. Do not edit files under `assets/brand/` when changing app assets. See [companion play](../../docs/macos-companion-play-plan.md).

There is no test target. After Mac UI changes, run the app and check wake/tuck, persona switch, dragging with chat open, tap-to-toggle chat, close/reopen draft retention, multiline and blank prompts, Command-Return, Escape, and hub window focus through the grid button. Check that chat remains visible near screen edges and that long prompts scroll without covering the composer. For companion play, also check hover face, drag squash and land bounce, idle hey/zzz then wake on hover, peek toward the pointer, double-tap spin, right-click actions, first-chat confetti once per persona, and that Reduced Motion kills the motion toys.

On **My Mac**, also check Sign in with Apple from the status menu: a fresh launch is signed out; a successful sign-in shows a UID; quit and reopen restores that UID without another sheet; Sign Out returns to signed out; canceling the Apple sheet does not invent a UID. Compare the Mac UID with a provider-linked iOS Profile.
