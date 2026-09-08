# macOS: develop the floating Agent experience

**Status:** Planned — no phase started
**Created:** 2026-09-06

Living implementation plan for the next three macOS phases: finish the Agent's chat UX, connect real AI conversation, and complete one computer-use task. Existing chat UI is the starting point. This plan does not mean the planned capabilities are implemented or that a model provider has been selected.

## Product model

- **CAOCAP** is the Mac app and Agents Hub: explore, build, and collaborate on agents.
- **The Agent** is the cute floating head on the desktop. Tap it to open its own compact chat and give it prompts.
- **CoCaptain** is the platform-provided default agent. CoStar is also available in the current persona picker.
- The Agent will use computer-use skills to carry out the user's requests. Its chat is where the user directs that work, follows progress, and gets results.
- The hub window and the floating Agent are separate surfaces. Closing the hub window leaves the Agent available; quitting the app ends the process.

Do not turn this into a hub window with “Workstation” and “Agent Studio” tabs. The chat belongs to the floating Agent.

## Starting point

The current Mac app has:

- A placeholder CAOCAP hub window, app icon, and menu-bar status item.
- A draggable floating Agent with show/hide and CoCaptain/CoStar switching.
- A compact chat beside the Agent, with suggestions, a multiline composer, and scrollable prompt history.
- Separate session-only drafts and prompts for each persona. Prompts are marked **Not sent**; no AI service receives them.
- Close/reopen chat, keyboard access, and an Open CAOCAP button that focuses or reopens the hub.

The app has built successfully. Initial UI checks covered opening chat, prompt entry, scrolling, and draft retention. Native dragging, persona switching, and visibility checks still need a complete pass. There is no macOS test target.

See [macOS setup and current behavior](../apps/macos/README.md). The initial chat work is recorded in commit `49f470e`.

## How we work

- Work on one phase at a time. Start implementation when the user asks to start that phase or explicitly authorizes several phases.
- Before a phase, explain its visible result and resolve the decisions that materially affect it. Do not infer extra product features from reusable code.
- Keep changes small and leave macOS buildable after each phase.
- Keep useful components; remove obsolete behavior and content when replacing it.
- Assume no existing users. Do not add compatibility migrations without a concrete need.
- After a phase, report what changed, how to try it, validation results, limitations, and the next phase. Wait for the next go-ahead unless continuing is already authorized.
- Commit and push only when requested. Update this file as decisions and checks are completed.

## Phase overview

| Phase | Visible result | Status |
| --- | --- | --- |
| 1. Finish chat UX | The floating Agent's chat feels right and behaves consistently on Mac. | Initial UI refined |
| 2. Connect AI conversation | The user can have a real conversation with CoCaptain, stop a response, and recover from errors. | Completed; live streaming implemented |
| 3. Complete one computer-use task | A prompt leads to real work in a chosen app and an inspectable result. | Next |

## Phase 1 — Finish the floating Agent's chat UX

**Status:** Not started; initial UI exists

**Outcome:** A compact, usable chat that clearly belongs to the floating Agent and works independently of the hub window.

### Decisions to settle

- Review the running chat with the user: size, placement, artwork, colors, spacing, and empty-state wording.
- Confirm opening and dismissal behavior, keyboard shortcuts, and what clicking elsewhere should do.
- Decide whether conversation history should survive quitting the app. The current baseline is session-only; durable history is not implicitly included.
- Confirm how switching between CoCaptain and CoStar should affect the visible conversation and draft.

### Work

- [ ] Review and refine the existing chat instead of rebuilding the hub.
- [ ] Finalize the composer, submission gesture, multiline editing, and empty-input behavior.
- [ ] Finalize prompt history, text selection, scrolling, and draft retention.
- [ ] Verify tap versus drag, chat placement after dragging, and screen-edge handling.
- [ ] Verify close/reopen, show/hide, persona switching, and keyboard focus.
- [ ] Check light/dark appearance, readable contrast, accessibility labels, Reduced Motion, and Reduce Transparency.
- [ ] Keep the preview limitation visible while no AI service is connected.
- [ ] Document the agreed behavior and any remaining design decisions.

### Completion checks

- Tapping the head opens its chat; the agreed dismissal actions close it.
- Dragging moves the Agent without accidentally opening or closing chat.
- Chat stays usable near screen edges and after changing displays; verify on multiple displays when available.
- Long drafts and conversations scroll without covering the composer or close control.
- Draft/history behavior matches the agreed policy across closing chat, changing persona, hiding the Agent, and quitting.
- Closing the hub leaves chat usable. Open CAOCAP focuses the existing hub or reopens it after closure.
- The user has reviewed the running UI, the Mac build passes, and untested cases are recorded.

**Not in this phase:** AI service integration or computer-use execution.

## Phase 2 — Connect real AI conversation

**Status:** Completed
**Depends on:** Phase 1

**Outcome:** The user sends a prompt through the Agent's chat and receives a real response, with clear control over the conversation.

### Decisions settled

- Provider & model: Firebase AI Logic (`gemini-flash-latest`) using the existing `GoogleService-Info.plist`.
- System persona & tone: Mirrored after iOS CoCaptain (patient, encouraging mentor) and CoStar (visionary creative partner).
- Session scope: Multi-turn conversations persist in memory across chat window closures and persona switches, and reset when quitting CAOCAP.
- Desktop companion reactions: Head reacts to the generation lifecycle (Thinking face while streaming, Celebrating face briefly on completion, Confused face on error).

### Work

- [x] Add the smallest service integration needed for text conversation (`AgentLLMService.swift` using `FirebaseAILogic`).
- [x] Connect the composer to a real request and display streamed replies when supported.
- [x] Distinguish pending, responding, completed, stopped, and failed turns using actual service state.
- [x] Add Stop and an understandable retry path. Retain the user's prompt after failure.
- [x] Keep replies attached to the originating conversation and persona, including after switching or closing chat.
- [x] Show connection/setup failures clearly and remove preview wording only where the live connection replaces it.
- [x] Added dynamic composer controls (Stop button during stream, Send arrow when idle) and rich Markdown formatting.
- [x] Update setup documentation with the configuration actually selected.

### Completion checks

- A real prompt produces a real reply in the floating chat, and a follow-up uses the intended conversation context.
- Stop ends the active response; late events do not resume or overwrite a stopped turn.
- An unavailable connection or failed request leaves the prompt recoverable and provides a working retry path.
- Repeated submission and retries do not accidentally duplicate turns.
- Switching personas or closing/reopening chat follows the agreed policy and never displays another conversation's reply.
- Progress reflects actual activity; this phase does not claim to have operated other apps.
- The Mac build, relevant tests, and the live conversation flow pass.

**Not in this phase:** Controlling apps, adding an agent marketplace, or importing the iOS feature stack.

## Phase 3 — Complete one computer-use task end to end

**Status:** Not started
**Depends on:** Phase 2

**Outcome:** The user gives CoCaptain a request, the Agent operates a chosen application, and the user can inspect the completed work.

### Decisions to settle

- Select one target application, one task, and an observable definition of success.
- Choose the execution environment: the user's current Mac desktop or a separate computer workspace. This remains open; the chat layout does not decide it.
- Select a computer-use runtime and confirm feasibility with the app's macOS permissions, sandbox, and distribution approach.
- Define how the user sees current activity, stops execution, handles requests for input, and takes back control.
- Agree how hiding chat, hiding the Agent, or quitting affects an active task.

**Candidate task to discuss:** Ask CoCaptain to create a short packing list in TextEdit and save it to a user-selected folder. The user opens the saved document and checks its contents. This is an example, not a selected requirement.

### Work

- [ ] Connect the chosen computer-use capability to the Agent's request loop.
- [ ] Let the Agent observe the target app, choose an action, perform it, and observe the result before continuing.
- [ ] Show concise activity in chat, including when the Agent needs user input.
- [ ] Provide a visible Stop control that prevents further actions and leaves the current outcome understandable.
- [ ] Handle missing permissions, an unavailable target app, interruption, and execution failure without claiming success.
- [ ] Return an inspectable result, such as the actual saved file, and distinguish completed work from partial work.
- [ ] Verify the result from the target application or resulting artifact rather than relying on the Agent's final message.
- [ ] Document the supported task and the actual operating requirements.

### Completion checks

- The task starts from a natural-language prompt in the floating Agent's chat.
- CoCaptain performs real computer-use actions; a canned animation, fabricated progress, or fixed demonstration script does not satisfy this phase.
- The user can follow activity and stop further actions during execution.
- A successful run produces the agreed, independently inspectable result.
- A stopped or failed run reports what happened and what, if anything, was already changed.
- The same task works again from a fresh starting state with a variation in the requested content.
- The Mac build, relevant tests, and a live end-to-end demonstration pass. Environment limitations are documented.

**Not in this phase:** Several agents controlling the same desktop, unattended scheduling, broad app coverage, or a general automation platform.

## Validation and phase wrap-up

Run from the repository root with a compatible full Xcode installation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apps/macos/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/caocap-macos-build CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Run the app on **My Mac** for the changed flow. Add and run focused automated tests when the phase introduces service or execution logic. A successful build is not evidence that a conversation or computer-use task works.

For each phase, record:

- Decisions made and the behavior delivered.
- Build, automated test, and live UI results separately.
- Any blocked or untested checks and how to reproduce them.
- The user's review and remaining changes before marking the phase Done.

## After these phases

Review what the working Agent experience teaches us before selecting the next slice. Explore, Build, and Collaborate remain essential to the CAOCAP hub, but implementing those surfaces is a separate plan. iOS remains an independent project; its large/medium sheets and long-press rules are not automatically Mac requirements.

Related references: [product vision](product-vision.md), [SRS and open decisions](SRS.md), [macOS setup](../apps/macos/README.md), [companion play](macos-companion-play-plan.md), and [completed iOS stripping plan](ios-pivot-plan.md).
