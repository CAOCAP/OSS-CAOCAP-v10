# CoCaptain Feature

CoCaptain is the in-app assistant. It talks about the current canvas, keeps a sign-in-aware conversation, and can request canvas actions such as creating or moving a card. It does not propose or apply HTML, SRS, or Mini-App source edits. In Agent mode it can also send the allowlisted Open YouTube on Mac command. Ask / Plan stay prose-only.

CoCaptain and CoStar are separate default agents on Home. Each Workspace selects its own canvas-backed conversation archive, chat title, avatar, and session draft. The FAB is available inside that Workspace. Ask / Plan modes stay prose-only.

## Ownership

- `Chat/` owns the adaptive CoCaptain sheet, shared chat visual language, grouped project conversation browser, lazy timeline, bubbles and on-demand message actions, typed progress/errors, context-aware input composer (Agent/Ask/Plan mode, optional `@` pin, route disclosure, and `cocaptain.chatMode` persistence), streaming task lifetime, and direct command handling.
- `AgentContract/` owns the machine-readable agent contract: coordinator, parser, output adapters, validator, typed review drafts, and shared agent/review/timeline models.
- `Review/` owns `CoCaptainReviewLifecycle` plus Review Bundle rendering for human approval of **app actions**. HTML / SRS node-edit proposals are not staged.
- `Analysis/` owns structural parser warnings and project recommendations from the analyzer.
- `NodeAgent/` owns the embedded node-scoped chat interface.

Supporting services live outside this feature:

- `ProjectContextBuilder` serializes the canvas for the model (cards and connections, not HTML/SRS).
- `CoCaptainConversationStore` persists project-scoped timelines, active conversation selection, and reading position in a versioned local sidecar keyed by canvas file name.
- `LLMService` routes and streams from Firebase AI Logic or local LiteRT-LM; `LocalGemmaModelManager` owns the downloaded model and local sessions. On-device Gemma is available on the iPhone 15 Pro family and newer iPhones, plus M-series iPads; unsupported devices use Gemini cloud.
- `AppActionDispatcher` performs high-level app actions such as create or move a node.

## Agent Flow

1. The user picks Agent, Ask, or Plan in the composer (persisted as `cocaptain.chatMode`, default Agent) and sends a message through `CoCaptainViewModel`.
2. Direct commands are resolved locally with `CommandIntentResolver` when possible. In Ask/Plan modes, mutating shortcuts and Open YouTube on Mac are skipped so those messages go to the model as chat.
3. Otherwise, `CoCaptainAgentCoordinator` builds project context from the active `ProjectStore`. In project scope, an optional `@` pin focuses the prompt on one card via `buildNodePromptContext` without switching to a node-scoped session.
4. `CoCaptainTurnPlan` merges turn purpose with the selected `CoCaptainChatMode` to choose the effective execution policy.
5. `LLMService` streams text back into the current assistant bubble. Offline turns automatically use a ready local Gemma model without changing the saved online preference.
6. `CoCaptainAgentOutputAdapter` hides machine output while streaming and turns the final response into a directive. Proposed HTML / SRS patches are dropped.
7. For structured turns, `CoCaptainAgentValidator` checks action IDs and action safety. Executable work is enforced only when the policy requires it (onboarding guided edit), not for standard Agent chat.
8. Safe actions execute immediately when autonomous; validated pending canvas actions leave the coordinator as a typed review draft.
9. `CoCaptainReviewLifecycle` stages that draft into a Review Bundle without performing pending actions. Leftover HTML-edit review items, if any, conflict instead of applying.

Free-usage and subscription prompts are product CTA timeline items, not review bundles.

## Conversation Continuity

Project-scoped CoCaptain keeps a local conversation archive outside
`ProjectSnapshot`, so conversation attachments and long timelines do not slow
ordinary canvas saves or require a project schema migration. Each canvas has an
independent active conversation, and builders can create, search, switch,
rename, and delete chats without affecting nodes, checkpoints, or snapshots.

Switching or restoring a conversation resets the underlying model session, then
replays a bounded recent transcript on the next turn. Review Bundles remain
attached to the conversation where they were proposed and are restored into the
Review Lifecycle before a decision can be made. Node-scoped messages continue
to use `NodeAgentState`.

Explicit **Stop** cancels a turn. Dismissing CoCaptain does not: the shared view
model keeps streaming, persists the completed result, and shows it when the
surface reopens.

## Turn Execution Modes

`CoCaptainTurnPlan` merges `CoCaptainTurnPurpose` with `CoCaptainChatMode` into a `CoCaptainTurnExecutionPolicy` in `CoCaptainAgentModels.swift`. The coordinator reads `turnPlan.effectivePolicy` instead of hardcoding onboarding exceptions. Onboarding purposes override the chat mode; standard turns follow the composer’s Agent/Ask/Plan selection (`chatMode`, default Agent, persisted under `cocaptain.chatMode`). Project-scoped and node-scoped CoCaptain share that same stored mode.

| Policy | When | Structured tools | Enforce edit | Agentic retry | Execute / stage | Context |
|------|------|------------------|--------------|---------------|-----------------|---------|
| Agent | Standard turn + `.agent` mode | Yes | No — pure chat OK | Yes — invalid structured output only | Yes when the model emits canvas work | Implementation |
| Ask | Standard turn + `.ask` mode | No | No | No | No — prose only | Product |
| Plan | Standard turn + `.plan` mode | No | No | No | No — outline prose only | Product |
| Conversational | `.onboardingWelcome`, `.onboardingBuildHandoff` | No | No | No | No — prose only | Product |
| Agentic (onboarding) | `.onboardingGuidedEdit` | Yes | Yes | Yes — missing or invalid work | Yes — stages a guided canvas action for review | Implementation |

Do not reintroduce keyword intent classification. Agent mode must finish pure prose turns without “must include an edit” failures.

Ask, Plan, and conversational turns still receive canvas context and mode/purpose prompt instructions, but the agent contract block is omitted from the LLM prompt and action catalogs are not passed. Plan prompts steer toward numbered step outlines without implementing changes. If the model disobeys and emits `cocaptain_actions`, the coordinator ignores the payload and surfaces visible prose only.

When adding a new turn purpose, declare its execution policy in the same enum switch as its prompt instructions. When changing mode → policy mapping, update the turn-plan / coordinator policy tests.

## Structured Payload Contract

Canvas actions use Gemini function calling through `request_app_action`, or a trailing XML block:

```xml
<cocaptain_actions>
  <assistant_message>Visible fallback text.</assistant_message>
  <clarifying_question prompt="One short question when the request is too vague to act on">
    <option>First concrete outcome</option>
    <option>Second concrete outcome</option>
  </clarifying_question>
  <safe_actions>
    <action id="id" />
  </safe_actions>
  <pending_actions>
    <action id="id" />
  </pending_actions>
</cocaptain_actions>
```

Rules:

- The parser uses the last `cocaptain_actions` tag in the response.
- Malformed XML falls back to visible text with no payload.
- `safeActions` may only contain available, non-mutating, autonomous actions.
- `pendingActions` are shown for review before execution and are required for mutating or non-autonomous app actions.
- `node_edit` / `propose_node_edit` HTML and SRS patches are ignored. CoCaptain talks instead of offering “apply this HTML change.”
- `clarifying_question` needs a non-empty `prompt` and 2–4 non-empty options; malformed questions degrade to prose. A question-only payload counts as valid agentic work.
- Prompt rules keep the mentor tone: never refuse, use plain non-technical language, and ask exactly one clarifying question with outcome-phrased options when unsure.

Invalid structured payloads are not partially executed. The coordinator retries once with parse or validation feedback. If the retry is still invalid, the user sees a recovery question rather than a silent no-op or unsafe action.

If this payload changes, update parser/coordinator tests and the prompt contract in `LLMService`.

## Node-Scoped Review Persistence

Unresolved Review Bundles on node-scoped CoCaptain sessions are JSON-encoded by
`CoCaptainReviewLifecycle` into `NodeAgentState.pendingReviewBundlesData` and
restored when the node CoCaptain panel reopens. Both `.pending` and
`.needsClarification` are unresolved. Project-scoped Review Bundles are stored
inside their `CoCaptainConversationStore` timeline sidecar and restored when
that conversation becomes active.

Clearing node chat history also clears persisted pending review bundles.

Review cards with a target node include **View on Canvas**, which flies the workspace viewport to that node while CoCaptain stays open.

## Editing Guidance

- Keep sheet UI rendering in `Chat/CoCaptainView`; keep timeline and async state in `Chat/CoCaptainViewModel`.
- Keep Review Bundle staging, decisions, conflicts, checkpoints, and node persistence behind the `CoCaptainReviewLifecycle` interface.
- Assistant chat bubbles may render Markdown for readable explanations, but raw structured payloads must stay hidden.
- Keep model orchestration in `AgentContract/CoCaptainAgentCoordinator`.
- Keep payload parsing deterministic and tolerant of malformed model output.
- Prefer adding new app capabilities through `AppActionDispatcher` and `AppActionID`.
- Do not leak raw structured payload text into the visible chat timeline.
- Be careful with cancellation: only explicit Stop cancels streaming; dismissing and reopening the chat must preserve the active turn.
- Keep project conversation persistence in `CoCaptainConversationStore`; do not add large chat timelines or attachments to `ProjectSnapshot`.
- Keep validation near the coordinator boundary. SwiftUI views should render review state, not decide whether model output is safe.
- Keep raw model wire formats behind output adapters. The coordinator should consume directives, not Firebase/Gemini-specific response parts.
- Keep canvas work in `request_app_action`. Do not restore Mini-App HTML/SRS patch tools.
- Keep free-tier quota enforcement in `LLMService`/`TokenUsageLimiter`; CoCaptain UI should only surface quota state when a hard limit blocks a request, then route upgrades through a product CTA.

## Verification Checklist

- Send a normal chat message and confirm streaming text appears. CoCaptain does not offer to apply an HTML change.
- Dismiss CoCaptain during streaming, reopen it, and confirm the same turn continues.
- Create, rename, search, switch, and delete project conversations; confirm each canvas restores its own active chat.
- Confirm assistant Markdown renders cleanly and message text can be selected, copied, shared, retried, and rated.
- Confirm user messages can be copied, restored into the composer for editing, and resent.
- Stop a response and confirm its partial prose remains with a recoverable Continue card.
- Simulate model/network/attachment/quota failures and confirm each has distinct recovery copy.
- Switch Agent ↔ Ask from the composer chip; confirm the placeholder updates and the choice survives relaunch (default Agent).
- Pin a card with `@` in project CoCaptain; confirm the next turn’s context focuses that node; clear the pin and confirm full-canvas context returns.
- Ask to create or move a card and confirm a review bundle can stage that canvas action.
- Switch to Ask and send the same prompt; confirm prose-only reply with no review staging.
- Open node-scoped CoCaptain and confirm it uses the same Agent/Ask/Plan selection.
- Send a direct navigation command and confirm safe actions execute or review appears as expected.
- In Agent mode, say “open YouTube on my Mac” with a signed-in Mac that has requests enabled; confirm chat shows the receipt and YouTube opens. Ask mode with the same phrase must stay prose-only.
- On iPhone and iPad, confirm CoCaptain opens as a detented sheet (large from FAB tap / ⌘J, medium from the FAB Chat bubble).

## Test Targets

Useful test coverage for this feature:

- parser success, malformed XML fallback, and trailing fence behavior.
- coordinator safe action execution and review bundle generation for canvas actions.
- validator rejection for unknown actions, unsafe safe actions, and unavailable pending actions.
- function-call adapter mapping for safe actions and pending actions.
- HTML / SRS `propose_node_edit` and `node_edit` payloads are dropped.
- Review Lifecycle staging and transitions for app actions, including unavailable actions, bulk decisions, and node-only persistence.
- direct command handling for autonomous vs review-required actions; Ask skips mutating short-circuits and Open YouTube on Mac.
- Agent pure-prose turns finish without forced edit retries.
- Ask never stages a review bundle from model output.
- turn-plan policy mapping for Agent, Ask, and onboarding purposes.
- conversation archive encoding, per-project isolation, unsupported schema handling, and deletion.
- retry/edit metadata preservation, explicit-stop behavior, background dismissal, and typed error transitions.
