# App Session

Owns the agent hub tab selection, local library, selected agent, Workspace routing, global sheet flags, and `AppActionDispatcher` registration. Home is an agent grid. Explore, Communities, and the creation wizard currently have placeholder destinations.

## Ownership

- `AppSessionCoordinator` is the single session owner created by `ContentView`.
- `AgentLibrary` (in `Features/home/`) persists local Home membership. The coordinator caches a chat view model per agent so drafts remain separate.
- `AppRouter` (in `Navigation/`) owns Workspace navigation and `ProjectStore` instances. Opening an agent resets its navigation stack and selects its stable canvas filename.
- `AppActionDispatcher` (in `Services/AppActions/`) still owns action definitions; the coordinator registers handlers that mutate session/UI state. Open YouTube on Mac homepage, YouTube watch-URL, and documentation-URL commands are registered here and executed through `RemoteMacCommandRunner`.
- `App/Shell/` contains SwiftUI modifiers and helpers that bind to the coordinator without adding business rules.
- The Activity node sets `showingActivity`; `AppSheetsModifier` presents the
  feature-owned expanded activity sheet.

## Editing Guidance

- Add new global sheets or presentation flags to `AppSessionCoordinator`, then wire them in `App/Shell/AppSheetsModifier.swift`.
- Add new app-level actions by registering handlers in `AppSessionCoordinator.configureActions()` and exposing them through the dispatcher.
- Keep feature-specific UI in `Features/*`; keep cross-cutting session wiring here.
- When onboarding or CoCaptain presentation rules grow, prefer extracting focused helpers over expanding the coordinator indefinitely.
- First-run handoffs: `finishIntroFlow()` → persona pick; `finishPersonalizationFlow()` → Home. The tutorial engine still exists, but the lesson catalogue is empty so first-run does not start a walkthrough.

## Related Tests

- `caocapTests/AppSession/AppSessionCoordinatorTests.swift`
