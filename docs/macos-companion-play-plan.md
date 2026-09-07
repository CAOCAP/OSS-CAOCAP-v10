# macOS companion play

Living handoff for the floating Agent's local character toys. This is **not** the chat/AI/computer-use work in [macos-agent-plan.md](macos-agent-plan.md). CoCaptain and CoStar share one pet via the existing persona switcher.

## Architecture

`CompanionPanel` forwards hover, drag, tap, double-tap, and right-click. `CompanionController` polls the pointer and dispatches `CompanionPlayEvent`s. `CompanionPlay` holds mood, motion, bubble text, and confetti, then fans events out to directors. `CompanionView` only composites that state.

Mood and bubble claims use priority: transient > interaction > idle > rest. Rest bubble is "Let's talk" while chat is open and "Chat with me" otherwise.

Reduced Motion disables bob, squash, peek, spin, and confetti. Instant mood and bubble changes still happen.

## File ownership

| File | Role |
|------|------|
| `apps/macos/caocap/caocap/features/companion/play/CompanionPlay.swift` | Dispatcher, claims, context menu host |
| `apps/macos/caocap/caocap/features/companion/play/CompanionMoodDirector.swift` | Sprite swaps |
| `apps/macos/caocap/caocap/features/companion/play/CompanionSquashBounce.swift` | Drag squash and drop spring |
| `apps/macos/caocap/caocap/features/companion/play/CompanionIdlePersonality.swift` | Hey / Hi bubble and sleepy tuck |
| `apps/macos/caocap/caocap/features/companion/play/CompanionCursorPeek.swift` | Lean toward nearby pointer |
| `apps/macos/caocap/caocap/features/companion/play/CompanionDropToys.swift` | Spin, Wave hello, first-chat confetti |
| `apps/macos/caocap/caocap/features/companion/play/CompanionConfetti.swift` | Confetti overlay |

Directors write only their fields. Register a new director with one line in `CompanionPlay.init`.

## Mood mapping

Knocked-out avatar heads live in `apps/macos/caocap/caocap/resources/Assets.xcassets`. Do not edit `assets/brand/`.

| Mood | CoCaptain | CoStar |
|------|-----------|--------|
| idle | `CoCaptainIdle` | `CoStarIdle` |
| thinking | `CoCaptainThinking` | `CoStarThinking` |
| celebrating | `CoCaptainCelebrating` | `CoStarCelebrating` |
| confused | `CoCaptainConfused` | `CoStarThinking` (no confused art) |

Hover and drag use thinking. Drop and first chat use a brief celebrating face. Wave hello uses confused plus a "Hello!" bubble.

## Motion fields

- Squash: `motion.squashScale` and `isBobPaused`
- Peek: `motion.peekOffset` when the pointer is within 120pt and not over the panel
- Spin: `motion.spinDegrees`
- Idle bob: `bobAmplitude` (3pt, 1.2pt when sleepy) animated in `CompanionView`

## Toys

- Double-tap spins. The first click of a double-click may still toggle chat.
- Right-click menu: Spin, Wave hello.
- First chat open per persona in this install bursts confetti (`companion.didCelebrateChat.<persona>`).
- After ~20s still: "Hey!" / CoStar "Hi!" for 3s. After ~45s: "zzz" and a smaller bob. Open chat and hover suppress sleepy.

Chat remains a local preview. Prompts are not sent.
