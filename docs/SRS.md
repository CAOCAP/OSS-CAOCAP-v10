# CAOCAP Software Requirements Specification

| Field | Value |
| --- | --- |
| Document version | 0.6 Draft |
| Product | CAOCAP |
| Status | Draft for review |
| Owner | Azzam Alrashed |
| Reference model | ISO/IEC/IEEE 29148:2018 |

## Revision history

| Version | Date | Description |
| --- | --- | --- |
| 0.1 Draft | 2026-09-04 | Established the initial SRS structure. |
| 0.2 Draft | 2026-09-05 | Clarified the product as a computer-use AI agent for digital-skills learners, primarily focused on coding and earning income. |
| 0.3 Draft | 2026-09-05 | Aligned the scope with Explore, Build, and Collaborate; drafted requirements, verification criteria, and open decisions for the collaborative agent platform. |
| 0.4 Draft | 2026-09-06 | Recorded mindmaps for agent context and knowledge, flowcharts for logic and conditional flows, and iOS and macOS as the first development platforms. Updated requirements and remaining design decisions. |
| 0.5 Draft | 2026-09-06 | Documented the playful building experience, with proposed requirements for canvas feedback, execution highlighting, first-run celebrations, visual clarity, and reduced motion. |
| 0.6 Draft | 2026-09-06 | Recorded the current macOS shell (app icon, menu-bar status item, floating CoCaptain companion) without adding companion requirements. |

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) defines the intended behavior and requirements of CAOCAP, a platform for discovering, building, and publishing AI agents together.

It provides a shared reference for planning, design, implementation, and verification. Confirmed requirements and unresolved decisions are recorded separately. A documented requirement does not imply that the capability has been implemented.

### 1.2 Scope

CAOCAP is a platform where people discover, build, and publish AI agents together. Its core experiences are Explore, Build, and Collaborate.

The intended system supports discovering and trying agents, creating projects, defining agent behavior, connecting tools and knowledge, testing agents, reviewing contributions, and publishing versions for others to use. It also supports improving published agents through feedback and continued collaboration.

Users will build agents with mindmaps for context and the agent's knowledge base, and flowcharts for logic, operations, and conditional flows. Development will start with iOS and macOS, followed by the other platforms.

This SRS covers user-facing applications, agent projects, collaboration, testing, publishing, and interfaces to external services. Underlying AI models and third-party services are external systems.

The agent execution environment, publishing mechanism, supported integrations, and responsibilities of each client platform remain to be defined.

### 1.3 Intended audience

This SRS is intended for the product owner and contributors responsible for reviewing, designing, implementing, verifying, deploying, operating, and maintaining CAOCAP.

### 1.4 References

| ID | Document | Version or date | Relevance |
| --- | --- | --- | --- |
| `REF-001` | [ISO/IEC/IEEE 29148 — Requirements engineering](https://www.iso.org/standard/72089.html) | 2018 | SRS organization and requirements-engineering guidance. |
| `REF-002` | [CAOCAP Product Vision](product-vision.md) | Current | Approved product direction, audience, journeys, and principles. |
| `REF-003` | [Repository README](../README.md) | Current | Product summary, implementation status, and repository structure. |
| `REF-004` | [Repository guidance](../AGENTS.md) | Current | Development conventions and validation commands. |
| `REF-005` | [iOS setup](../apps/ios/README.md) | Current | Configuration required by the existing iOS application. |
| `REF-006` | [macOS setup](../apps/macos/README.md) | Current | Current Mac shell and how to run it. |

### 1.5 Requirement conventions

Requirement identifiers use the following format:

- `CAO-FR-nnn`: functional requirement.
- `CAO-IR-nnn`: external-interface requirement.
- `CAO-DR-nnn`: data requirement.
- `CAO-NFR-nnn`: quality or non-functional requirement.
- `CAO-CON-nnn`: constraint, assigned when a constraint is agreed.

`CAO-G-nnn`, `CAO-J-nnn`, and `CAO-OI-nnn` identify product goals, user journeys, and open issues respectively.

Requirements in sections 4.1–4.4 are **Proposed** in this draft. They translate the approved vision into behavior for review; their inclusion does not establish approval of every detail or selection for the first release. The development-order constraint in section 4.5 is **Approved**. No feature release priorities have been assigned. Each requirement's source identifies its rationale in the approved vision, including proposed engineering details derived from that rationale.

“Shall” states an observable obligation if the requirement is approved. Each requirement has one identifier and a verification criterion. Open issues record choices that must be resolved before dependent behavior can be finalized. An unresolved choice is not an implicit requirement.

Verification uses a test, inspection, or demonstration as specified in each row. A successful platform test need not mean that an AI-generated answer was correct: execution status and evaluation of agent behavior are separate results.

### 1.6 Terms

| Term | Meaning in this document |
| --- | --- |
| Agent | A configured AI capability with a defined purpose, instructions, and any tools or knowledge needed for its tasks. |
| Project | The workspace in which people build and maintain an agent and its supporting contributions and tests. |
| Mindmap | The visual structure users build and edit to organize an agent's context and knowledge base. How this content is selected for a run remains to be defined. |
| Flowchart | The visual structure users build and edit to define an agent's operations, logic, and conditional paths. Its exact execution semantics remain to be defined. |
| Revision | An identifiable state of an agent's configuration that can be associated with tests and contributions. The storage mechanism is undecided. |
| Contribution | Proposed instructions, tools, knowledge, mindmap or flowchart changes, tests, or feedback associated with a project and a contributor. |
| Test case | An example task with an input and an expected behavior used to evaluate an agent. |
| Run | An attempt to execute an agent against an input, producing an outcome or an execution failure. |
| Published version | An identifiable revision made available for others to use. This term does not specify where it executes or how it is distributed. |
| Authorized user | A user permitted to perform a particular action under the project's access rules. Permission roles remain to be defined. |

## 2. Overall description

### 2.1 Product context

CAOCAP connects people exploring agents with people building and improving them. A project provides continuity between configuration, contributions, testing, and publication. Published agents give explorers something to try, and their feedback can inform further project work.

CAOCAP is responsible for its project and collaboration experience and the interfaces it provides to agent execution and external services. The approved vision does not determine whether execution is local, hosted, or delegated to another service.

### 2.2 Product goals

These goals summarize the approved product vision in `REF-002`.

| ID | Goal |
| --- | --- |
| `CAO-G-001` | Help people discover agents and assess their suitability for relevant tasks. |
| `CAO-G-002` | Help builders turn ideas into testable agents using mindmaps for context and knowledge and flowcharts for logic and conditional flows. |
| `CAO-G-003` | Enable people to contribute to shared projects with understandable changes and attribution. |
| `CAO-G-004` | Enable builders to publish identifiable, tested versions with clear descriptions and limitations. |
| `CAO-G-005` | Support continued improvement through feedback, test results, and collaboration. |

### 2.3 Stakeholders and user classes

| User class or stakeholder | Description | Primary needs |
| --- | --- | --- |
| Explorer | A person looking for agents that address their needs. | Discover agents, understand their capabilities and limitations, and try them. |
| Builder | A person turning an idea into a working agent. | Create a project, organize context and knowledge in mindmaps, define behavior in flowcharts, test it, and publish it. |
| Collaborator | A person contributing to a shared project. | Contribute knowledge, tools, instructions, tests, or feedback and review changes. |
| Product owner | The person responsible for product direction and requirement decisions. | Resolve open issues, set release priorities, and review acceptance evidence. |

Explorer, Builder, and Collaborator are overlapping audience classes, not access-control roles. The experience should support newcomers, experienced builders, and teams. Account requirements and project permissions remain open under `CAO-OI-004`.

### 2.4 Operating environment

Development starts with iOS and macOS; development of the other platforms follows. This sets development order without establishing simultaneous release dates or identical client capabilities.

The following describes the current repository, not a commitment to feature parity or release support for every platform.

| Area | Current state |
| --- | --- |
| iOS | SwiftUI canvas + CoCaptain + sign-in shell targeting iOS 26 or later, with a Pro purchase screen, unit tests, and UI tests. Home is a local agent library with CoCaptain and CoStar. Each opens a separate full-screen Workspace with the existing canvas and chat. Explore, Communities, and the creation wizard have placeholder destinations; discovery, acquisition, shared building, mind maps, and flowcharts remain planned. See the [iOS Home redesign plan](ios-home-redesign-plan.md). A provider-linked session publishes a Firestore device heartbeat; Profile can list other devices and request an allowlisted Open YouTube on Mac command. CoCaptain Agent mode can send that homepage command, or send an allowlisted documentation URL on developer.apple.com / Swift docs; Ask / Plan cannot. Service configuration is described in `REF-005`. |
| macOS | SwiftUI application targeting macOS 26.5, with an app icon, menu-bar status item, and floating Agent that opens its own compact chat UI. Firebase initializes from the shared iOS Apple app (`com.Ficruty.caocap`). The status menu can Sign in with Apple and restore that Firebase UID. A signed-in Mac publishes a Firestore device heartbeat and can list other devices on that account. An opt-in toggle can claim an allowlisted openYouTube homepage command, openYouTubeVideo watch URL, or openURL documentation page and open it in the default browser. Prompts are session-only and are not sent to an agent service; computer use is not implemented. The hub window is still placeholder content. There is no test target. Setup is described in `REF-006`. |
| Android, Windows, Linux, and web app | Directory scaffolds; their frameworks and shared services have not been selected. |
| Landing page | Vite waitlist prototype in `websites/landing/`, hosted on Firebase Hosting. Joining posts to the `joinWaitlist` function, which writes `waitlist/{email}` in Firestore. No notification email is sent yet. This is not the planned web application. |
| Development | Apple app builds require macOS and full Xcode with compatible SDKs; see `REF-004`. |

The collaborative platform capabilities described here are planned. Existing app code and dependencies do not establish the architecture or provider choices for those capabilities. Client responsibilities and release support are tracked in `CAO-OI-007`.

### 2.5 Assumptions and dependencies

The scope depends on the product direction in `REF-002`. Detailed architecture and operational assumptions have not been approved.

Trying and testing agents require an execution mechanism and supported model and tool interfaces. Publishing requires a defined way to make a version available. Shared work requires an identity and authorization model. These dependencies are recorded in `CAO-OI-001`, `CAO-OI-002`, `CAO-OI-004`, and `CAO-OI-008`; this draft does not select their implementations.

The existing iOS app requires its documented service configuration. Reusing that configuration or its providers for the platform remains an implementation decision.

### 2.6 Exclusions

The current scope covers CAOCAP and its interfaces to external systems. Building the underlying AI models or third-party services themselves is outside the scope defined in section 1.2.

No other permanent product exclusions have been agreed. A marketplace, payments, hosted execution, public source code, and specific integration providers are not established requirements of this draft. Their relevance and release scope remain to be decided in section 6. Mindmaps and flowcharts are the agreed building approach; their detailed interactions and configuration formats remain open.

## 3. System capabilities and user journeys

### 3.1 Capability groups

| Capability | Description |
| --- | --- |
| Explore | Discover agents, understand their purpose and limitations, try them, and find projects to contribute to. |
| Build | Create projects, organize context and knowledge in mindmaps, define logic and conditional flows in flowcharts, connect supported tools, and inspect test outcomes. |
| Collaborate | Propose and review contributions, including mindmap and flowchart changes, understand project permissions, and preserve attribution. |
| Publish and improve | Make an identifiable version available, communicate its behavior and limitations, and use feedback to guide updates. |

Publishing and testing connect the three core experiences; they do not establish additional product pillars.

### 3.2 Major user journeys

| ID | Journey | Successful outcome |
| --- | --- | --- |
| `CAO-J-001` | Explore and try an agent. | An explorer finds a relevant published version, understands its declared capabilities, and can inspect the outcome of trying it. |
| `CAO-J-002` | Build and test an agent. | A builder creates a project, organizes context and knowledge in mindmaps, defines operations and conditional flows in flowcharts, and inspects results tied to the revision tested. |
| `CAO-J-003` | Join and contribute to a project. | An authorized contributor proposes work, a reviewer can understand it, and accepted changes retain attribution. |
| `CAO-J-004` | Publish a version. | An authorized publisher reviews the revision and its test evidence, then makes an identifiable version available with a description and limitations. |
| `CAO-J-005` | Improve a published agent. | Feedback informs a project change that can be reviewed, tested, and published as an update. |

People may enter at different points, work independently, or participate only as explorers. These journeys do not require every user to complete the entire sequence.

## 4. Requirements

The functional, interface, data, and quality requirements below are proposed and have no assigned release priority. Section 4.5 records the approved development-order constraint. Access rules and supported integrations referenced below must be defined through the associated open issues before acceptance testing.

### 4.1 Functional requirements

#### Explore

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-FR-001` | The system shall present the published agents available to the current user under the applicable visibility rules. | Enable discovery. | `REF-002`: Explore | Test with available and unavailable publications; only available agents are shown. |
| `CAO-FR-002` | The system shall display a selected published version's purpose, limitations, declared tools, and declared knowledge sources. | Help users assess suitability. | `REF-002`: Trust through transparency | Inspect an agent's details against its publication record, including an agent with no tools or knowledge sources. |
| `CAO-FR-003` | The system shall provide a supported way to submit a task to a selected published version. | Let explorers try agents. | `REF-002`: Explore | Demonstrate submission and verify that the selected version receives the task through the chosen execution mechanism. |
| `CAO-FR-004` | The system shall display a run's execution status and its output or failure information when available. | Make trial outcomes understandable. | `REF-002`: Explore | Test an in-progress run, a completed run, and a failed run; verify the displayed status and outcome. |
| `CAO-FR-005` | The system shall let users discover projects available for their contributions under the applicable access rules. | Connect exploration to shared work. | `REF-002`: Explore | Test with accessible and inaccessible contribution projects after access rules are defined. |

#### Build and test

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-FR-006` | The system shall let an authorized user create a project with a stated agent purpose. | Establish a useful starting point. | `REF-002`: Build | Create a project and reopen it; verify that its purpose is retained. |
| `CAO-FR-007` | The system shall let an authorized user edit the project's agent instructions. | Define and refine behavior. | `REF-002`: Build | Save changed instructions and verify the saved revision contains them. |
| `CAO-FR-008` | The system shall let an authorized user configure supported tool connections for a project. | Give agents access to task capabilities. | `REF-002`: Build | Configure a supported tool and inspect the resulting project configuration. |
| `CAO-FR-009` | The system shall let an authorized user configure supported knowledge sources for a project. | Supply task context. | `REF-002`: Build | Configure a supported source and inspect the resulting project configuration. |
| `CAO-FR-010` | The system shall let an authorized user define a project test case with an input and an expected behavior. | Make evaluation repeatable. | `REF-002`: Test before publishing | Save and reopen a test case; verify its input and expected behavior. |
| `CAO-FR-011` | The system shall let an authorized user run selected test cases against an identified agent revision. | Evaluate a specific configuration. | `REF-002`: Build | Run a test and verify the executed input and revision against the selected case. |
| `CAO-FR-012` | The system shall display each test run's input, expected behavior, actual outcome, execution status, and tested revision. | Provide evidence for improvement. | `REF-002`: Useful outcomes | Inspect results from successful and failed executions; verify that execution failure is distinguishable from an unfavorable behavioral evaluation. |
| `CAO-FR-026` | The system shall let an authorized user create and edit mindmap nodes and relationships to organize a project's agent context and knowledge base. | Make mindmaps part of agent building. | `REF-002`: Build | Create, edit, connect, and remove mindmap nodes; reopen the saved revision and verify its content and relationships. |
| `CAO-FR-027` | The system shall let an authorized user create and edit flowchart steps and connections to define an agent's operations and conditional flows. | Make flowcharts part of agent building. | `REF-002`: Build | Configure connected operation and conditional steps; reopen the saved revision and verify the operations, conditions, and paths. |
| `CAO-FR-028` | When executing a supported conditional flowchart step, the system shall follow the path selected by that step's configured condition. | Make defined conditions affect agent behavior. | `REF-002`: Build | Test a supported condition with inputs that select different paths and verify the operations executed against the configured paths. |
| `CAO-FR-029` | The canvas shall snap a moved mindmap node or flowchart step to an eligible placement target under the agreed snapping rules. | Make arranging an agent feel responsive. | `REF-002`: Fun to build with | Move items within and outside the agreed snapping range on iOS and macOS; verify eligible placement and the resulting saved positions. |
| `CAO-FR-030` | The canvas shall provide visual feedback for the connection being drawn and whether the current endpoint is an eligible connection target. | Make connecting ideas and operations understandable. | `REF-002`: Fun to build with | Draw connections toward eligible and ineligible endpoints using the supported inputs on each client; verify feedback follows the gesture and clears when completed or canceled. |
| `CAO-FR-031` | During a test run, the flowchart shall highlight active steps and traversed connections according to observed execution events for the tested revision. | Let users see their agent's actual activity. | `REF-002`: Fun to build with; Trust through transparency | Exercise both paths of a conditional flow and an execution failure; compare highlights with execution events and verify unvisited paths are not highlighted as executed. |
| `CAO-FR-032` | The system shall show a brief, non-blocking celebration for an eligible first successfully completed run under the agreed milestone rules. | Acknowledge a building milestone. | `REF-002`: Fun to build with | Test an eligible first completion, a repeat completion, and a failed run; verify the celebration occurs only for the eligible first completion, does not block work, and acknowledges completion without claiming the answer is correct. |

Supported node and step types, condition semantics, and use of mindmap content during execution remain open under `CAO-OI-003`, `CAO-OI-008`, and `CAO-OI-015`.

Canvas feedback and celebrations describe the planned iOS and macOS experience. Snapping rules and supported inputs remain open in `CAO-OI-003`; visual details, animation timing, and milestone eligibility remain open in `CAO-OI-016`. Execution highlighting must reflect observed activity rather than simulated progress. A successfully completed run is distinct from a favorable evaluation of its answer.

#### Collaborate

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-FR-013` | The system shall provide a way for users to join shared projects according to the agreed membership rules. | Enable shared work. | `REF-002`: Intended user journey | Demonstrate allowed and denied joining scenarios after membership rules are defined. |
| `CAO-FR-014` | The system shall show who may contribute, change, and publish a shared project under its access rules. | Make control of shared work understandable. | `REF-002`: Ownership and attribution | Compare displayed permissions with the configured access rules for each action. |
| `CAO-FR-015` | The system shall let an authorized contributor submit proposed instructions, tool configuration, knowledge, mindmap or flowchart changes, tests, or feedback to a shared project. | Support different contribution types. | `REF-002`: Collaborate | Submit each supported contribution type, including mindmap and flowchart changes, and verify its association with the project and contributor. |
| `CAO-FR-016` | The system shall show a proposed change's author and its differences from the revision on which it was based. | Support informed review. | `REF-002`: Collaboration is part of building | Inspect proposals, including mindmap and flowchart edits, against their base revisions and verify the author and differences. |
| `CAO-FR-017` | The system shall let an authorized reviewer record acceptance or rejection of a proposed change. | Make review decisions explicit. | `REF-002`: Collaborate | Record each decision in separate scenarios and verify the recorded reviewer and outcome. |
| `CAO-FR-018` | The system shall apply accepted changes through the agreed review workflow while leaving rejected changes unapplied. | Connect review to shared project updates. | `REF-002`: Collaborate | Exercise accepted and rejected proposals and compare the resulting project revisions. |
| `CAO-FR-019` | The system shall display attribution for contributions incorporated into a project. | Credit shared work. | `REF-002`: Ownership and attribution | Incorporate contributions from two users and verify that both remain attributed. |

#### Publish and improve

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-FR-020` | The system shall present test evidence associated with the selected revision before an authorized user publishes it. | Inform the publication decision. | `REF-002`: Test before publishing | Select two different revisions and verify that evidence for one is not presented as evidence for the other; show missing evidence explicitly. |
| `CAO-FR-021` | The system shall let an authorized user publish an identified revision with its description and known limitations through the agreed publishing mechanism. | Make agents available for use. | `REF-002`: Intended user journey | Publish a revision and verify that an eligible explorer can access the resulting version and its description. |
| `CAO-FR-022` | The system shall report the outcome of a publication attempt as successful or failed when that outcome is known. | Avoid misleading release status. | `REF-002`: Trust through transparency | Test successful and failed publication attempts; neither an in-progress nor failed attempt is reported as published. |
| `CAO-FR-023` | The system shall let users submit feedback associated with a specific published version. | Connect use to improvement. | `REF-002`: Improve together | Submit feedback on two versions and verify that each item identifies the intended version. |
| `CAO-FR-024` | The system shall let an authorized user publish an updated revision as a distinct version of the same agent. | Support continued improvement. | `REF-002`: Improve together | Publish an update and verify that it has a distinct version identity linked to the same project. |
| `CAO-FR-025` | The system shall let authorized project users view feedback on the project's published versions. | Give builders and collaborators input for improvements. | `REF-002`: Improve together | Submit feedback and view it as an authorized project user; verify the associated version and exclusion of feedback from inaccessible projects. |

The test evaluation method and publication gate are unresolved in `CAO-OI-006`. These requirements do not establish an all-tests-pass rule or a minimum score.

### 4.2 External-interface requirements

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-IR-001` | The execution interface shall associate each returned outcome with the originating run and agent revision. | Keep execution results attributable. | `REF-002`: Test before publishing | Run two revisions with distinct inputs and verify correct result associations, including out-of-order completion. |
| `CAO-IR-002` | The system shall identify an unavailable or incomplete tool or knowledge connection when it prevents an attempted operation. | Help users resolve configuration problems. | `REF-002`: Clear and approachable | Attempt an operation with a missing or unavailable connection and verify that the affected connection is identified. |
| `CAO-IR-003` | The publishing interface shall return an identifiable publication outcome to the initiating project operation. | Link release status to the correct attempt. | `REF-002`: Intended user journey | Exercise separate publication attempts and verify their outcomes are associated with the correct revision and attempt. |

Specific APIs, protocols, supported formats, authentication methods, and integration providers remain open under `CAO-OI-001`, `CAO-OI-002`, and `CAO-OI-008`.

### 4.3 Data requirements

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-DR-001` | The system shall persist each project's identity, ownership, purpose, and agent revisions, including instructions, mindmap content and relationships, flowchart operations, conditions, and connections, and tool and knowledge configuration references. | Preserve work across sessions. | `REF-002`: Build; Ownership and attribution | Save and reopen a project in a new session; compare its stored mindmap, flowchart, other configuration fields, and revision identities. |
| `CAO-DR-002` | The system shall persist a contribution's project, contributor, submitted content, and, where applicable, base revision and review decision. | Preserve attribution and review context. | `REF-002`: Collaborate | Reopen submitted and reviewed contributions and verify their stored context. |
| `CAO-DR-003` | The system shall retain test evidence with its test input, expected behavior, actual outcome, execution status, and tested revision for the agreed retention period. | Support evaluation and publication review. | `REF-002`: Test before publishing | Retrieve retained evidence and verify each field; retention-boundary tests depend on `CAO-OI-011`. |
| `CAO-DR-004` | The system shall store each published version's identity, originating project and revision, publisher, description, declared tools and knowledge sources, and limitations. | Make releases identifiable and understandable. | `REF-002`: Trust through transparency | Inspect two versions of an agent and verify that their stored publication records match the respective revisions. |
| `CAO-DR-005` | The system shall associate stored feedback with the relevant published version. | Keep feedback actionable. | `REF-002`: Improve together | Retrieve feedback through its version and confirm it is not attributed to a different version. |

Retention periods, deletion behavior, storage limits, and treatment of externally changing knowledge sources remain open under `CAO-OI-008` and `CAO-OI-011`. Configuration identity alone does not guarantee repeatable model output or unchanged external data.

### 4.4 Quality requirements

| ID | Requirement | Rationale | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-NFR-001` | The system shall enforce the agreed access rules at the operation boundary for viewing restricted project content, changing projects, reviewing contributions, and publishing. | Preserve control of shared work. | `REF-002`: Ownership and attribution | Attempt each operation with permitted and denied identities, including direct interface calls where applicable. |
| `CAO-NFR-002` | The system shall not report an operation as successful when the underlying save, execution, or publication operation has failed. | Keep user-visible state truthful. | `REF-002`: Trust through transparency | Inject a failure in each operation type and verify that no success result is shown. |
| `CAO-NFR-003` | The system shall not automatically include credentials stored for tool or knowledge connections in shared descriptions, contribution views, or published artifacts. | Support appropriate information access. | `REF-002`: Ownership and attribution; Trust through transparency | Configure a connection with a distinguishable test credential and inspect system-generated shared views and published artifacts for its absence. |
| `CAO-NFR-004` | The system shall preserve the configuration identity of a published version when the originating project's working configuration changes. | Keep versions and test evidence meaningful. | `REF-002`: Intended user journey | Publish a version, edit the project, and verify that the published version still refers to its original configuration. |
| `CAO-NFR-005` | The agent-building canvas shall present rounded nodes and softly curved connections with labels readable under the agreed supported display and text-size settings. | Keep the playful canvas clear and approachable. | `REF-002`: Fun to build with | Inspect mindmaps and flowcharts on iOS and macOS at the agreed display and text-size settings; verify the specified shapes and readable node and connection labels. |
| `CAO-NFR-006` | The canvas shall use consistent category colors for knowledge, actions, and conditions, with labels or symbols that identify those categories independently of color. | Make purposeful color useful without making it the only cue. | `REF-002`: Fun to build with | Compare category styling across both clients and identify each category with color cues removed using its label or symbol. |
| `CAO-NFR-007` | With the platform's reduced-motion preference enabled, the canvas shall replace nonessential animation with reduced-motion or static feedback that preserves placement, connection, execution-status, and milestone information. | Preserve the experience without requiring decorative motion. | `REF-002`: Fun to build with | Repeat snapping, connection drawing, successful and failed execution, and an eligible celebration with reduced motion enabled on iOS and macOS; verify essential information remains available and work remains operable. |

The color-independent cues and reduced-motion behavior above are proposed accessibility requirements. Remaining measurable targets for accessibility, responsiveness, availability, capacity, and recovery remain open in `CAO-OI-010`; the visual specification remains open in `CAO-OI-016`.

### 4.5 Constraints

| ID | Constraint | Status | Source | Verification |
| --- | --- | --- | --- | --- |
| `CAO-CON-001` | Product development shall begin with iOS and macOS before development of the other client platforms. | Approved | `REF-002`: Development order; `REF-003`: Roadmap | Inspect the development plan and work milestones for iOS and macOS preceding other client development. |

Detailed client responsibilities, release dates, and feature scope remain open in `CAO-OI-007`. Existing repository conventions and build requirements are recorded in `REF-004`; they do not select the architecture of future clients or shared services.

No additional provider, commercial, or regulatory constraints have been approved. Unresolved choices are listed in section 6 rather than expressed as constraints.

## 5. Verification, acceptance, and traceability

### 5.1 Acceptance approach

1. Review the proposed requirements with the product owner and resolve decisions needed by the intended release.
2. Record which requirements are approved and selected for that release, including their priorities and any remaining dependencies.
3. Derive tests or inspection procedures from each selected requirement's verification criterion. Include normal operation and relevant denied-access, missing-configuration, and failure cases.
4. Validate the applicable user journeys using the selected clients, execution mechanism, integrations, and publishing model, including mindmap editing, flowchart editing, and conditional path behavior for the agent-building journey.
5. Record results against requirement IDs, the tested implementation revision, environment, and supporting evidence. Mark blocked and unexecuted checks explicitly.
6. Accept a release only when its agreed requirement checks and acceptance criteria are satisfied or a documented exception is approved by the product owner.

Platform verification and evaluation of an agent's task performance are separate. A build passing, a run completing, or an agent being published does not establish that its behavior is useful or correct. Agent evaluation methods and release gates must be agreed through `CAO-OI-006`.

For the playful building experience, cover eligible and ineligible snapping and connection targets, both conditional execution paths, execution failure, first and repeat successful runs, category recognition without color, and reduced-motion alternatives on iOS and macOS. Resolve the applicable visual and interaction criteria before treating these checks as acceptance evidence.

No implementation or verification status is asserted for the requirements in this draft. Current repository validation commands are in `REF-004`.

### 5.2 Traceability matrix

The matrix maps the approved vision to proposed requirement coverage and the approved development-order constraint. Identifiers listed as a range are inclusive. Shared requirements support more than one journey.

| Source in `REF-002` | Goals | Journeys | Requirement IDs |
| --- | --- | --- | --- |
| Explore; Trust through transparency | `CAO-G-001` | `CAO-J-001` | `CAO-FR-001` through `CAO-FR-005`; `CAO-IR-001`; `CAO-DR-004`; `CAO-NFR-002` |
| Build; Useful outcomes; Test before publishing | `CAO-G-002` | `CAO-J-002` | `CAO-FR-006` through `CAO-FR-012`; `CAO-FR-026` through `CAO-FR-028`; `CAO-IR-001`, `CAO-IR-002`; `CAO-DR-001`, `CAO-DR-003` |
| Fun to build with | `CAO-G-002` | `CAO-J-002` | `CAO-FR-029` through `CAO-FR-032`; `CAO-NFR-005` through `CAO-NFR-007` |
| Collaborate; Ownership and attribution | `CAO-G-003` | `CAO-J-003` | `CAO-FR-013` through `CAO-FR-019`; `CAO-DR-002`; `CAO-NFR-001`, `CAO-NFR-003` |
| Intended user journey; Test before publishing | `CAO-G-004` | `CAO-J-004` | `CAO-FR-020` through `CAO-FR-022`; `CAO-IR-003`; `CAO-DR-003`, `CAO-DR-004`; `CAO-NFR-001` through `CAO-NFR-004` |
| Improve together; Collaboration is part of building | `CAO-G-005` | `CAO-J-005` | `CAO-FR-023` through `CAO-FR-025`; `CAO-FR-007` through `CAO-FR-012`; `CAO-FR-015` through `CAO-FR-020`; `CAO-DR-005`; `CAO-NFR-004` |
| Development order | `CAO-G-001` through `CAO-G-005` | `CAO-J-001` through `CAO-J-005` | `CAO-CON-001` |

## 6. Open issues

These decisions are unresolved and do not authorize a particular implementation or business model. The product owner owns their resolution; contributors may investigate and propose options.

| ID | Decision needed | Affected areas | Owner | Status |
| --- | --- | --- | --- | --- |
| `CAO-OI-001` | Where do agents execute, which model providers are supported, and how are runs started, monitored, stopped, or limited? | Agent trials, testing, execution interfaces. | Product owner | Open |
| `CAO-OI-002` | What does publication deliver, who can access it, and how do updates, withdrawal, and existing users of older versions behave? | Discovery, distribution, publication records. | Product owner | Open |
| `CAO-OI-003` | With mindmaps and flowcharts selected for building agents, which node and step types, supported input methods, snapping rules and ranges, connection-target rules, condition definitions, and configuration formats apply? | Builder experience, contributions, validation. | Product owner | Open |
| `CAO-OI-004` | What accounts, membership rules, visibility settings, ownership changes, and permissions are required? | Joining, restricted content, project operations. | Product owner | Open |
| `CAO-OI-005` | Who can review or apply changes, how are conflicting contributions resolved, and how are concurrent edits handled? | Contribution lifecycle, history, data integrity. | Product owner | Open |
| `CAO-OI-006` | How is agent behavior evaluated, what evidence is required before publishing, and which results permit or prevent publication? | Test evaluation, publication gate, acceptance. | Product owner | Open |
| `CAO-OI-007` | With iOS and macOS development first, what can each client do, how are their releases sequenced, and which OS versions and later-platform milestones will be supported? | Release scope, interfaces, validation environments. | Product owner | Open |
| `CAO-OI-008` | Which tools and knowledge sources are supported, how is mindmap content selected and supplied as agent context, who provides credentials, and how are external data changes and access permissions handled? | Integrations, context selection, credentials, configuration traceability. | Product owner | Open |
| `CAO-OI-009` | How are agents and contribution projects organized, searched, or ranked? | Discovery and navigation. | Product owner | Open |
| `CAO-OI-010` | Beyond the proposed color-independent cues and reduced-motion behavior, what measurable readability, display and text-size support, accessibility, responsiveness, scale, availability, and recovery targets apply? | Quality requirements and acceptance tests. | Product owner | Open |
| `CAO-OI-011` | What data is retained, for how long, who can access it, and how do deletion and export work? | Projects, test inputs, outputs, history, feedback. | Product owner | Open |
| `CAO-OI-012` | Who pays execution costs, what usage limits apply, and are payments or agent monetization part of the product? | Operating model and release scope. | Product owner | Open |
| `CAO-OI-013` | What contribution and reuse terms, content rules, reporting, and moderation processes apply? | Shared work, attribution, publication, community use. | Product owner | Open |
| `CAO-OI-014` | Which proposed requirements are approved and prioritized for the first release? | Requirement baseline, milestones, acceptance. | Product owner | Open |
| `CAO-OI-015` | Does a flowchart define the entire agent workflow or selected operations within it, and where may the agent choose its own actions? | Flowchart execution, agent autonomy, test expectations. | Product owner | Open |
| `CAO-OI-016` | Which palette, typography, node and connection geometry, animation timing, and celebration treatment express the playful feel? What defines an eligible first-run milestone, including its scope and persistence across sessions? | Visual specification, feedback, first-run celebration, acceptance criteria. | Product owner | Open |

## 7. Document governance

The product owner is responsible for reviewing requirement proposals, resolving product decisions, and approving release scope. Contributors may propose changes with their rationale and affected requirements.

A requirement is **Proposed** until explicitly approved, **Approved** once its behavior is agreed, or **Retired** when it is superseded or removed. In version 0.6, the requirements in sections 4.1–4.4 remain Proposed with priority Unassigned; `CAO-CON-001` is Approved. The mindmap and flowchart building approach and playful product direction are confirmed, while their detailed interaction, execution, and visual requirements remain proposed. Record further approval and release-priority decisions against the affected identifiers.

Implementation and verification status are tracked separately from approval, with references to changes and test evidence. Approval does not imply implementation, and implementation does not imply acceptance.

Keep requirement identifiers stable. Do not reuse retired identifiers. When a requirement changes, update its rationale, verification criterion, related journeys, traceability, and affected open issues. Record material changes in the revision history and keep this SRS aligned with the product vision and README.
