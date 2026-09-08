# iPhone → Mac command protocol v2

Normative contract for the independent TypeScript and Swift clients. No legacy pending command without an expiry may execute. Clients never create/delete command documents. Owner means a non-anonymous Firebase UID, not a verified physical device.

`users/{uid}/commands/{requestId}` is created transactionally by an existing open callable or `createComputerUseTask({requestId, taskSummary})`. UUID identity survives retries; identical normalized input returns the existing ID, different input fails. Old open callers may omit the ID during cutover but receive no retry deduplication guarantee.

Immutable fields: schemaVersion=2, requestId, type (openYouTube/openYouTubeVideo/openURL/computerUse), url (null for computer use), taskSummary (trimmed, 1–500 UTF-16 units for computer use, otherwise null), target (com.apple.TextEdit for computer use, otherwise null), createdAt, expiresAt (createdAt + 60 seconds), reportingDeadline (createdAt + 300 seconds). All times originate from one backend Timestamp.

Mutable fields are initialized: status=pending; claimedByDeviceId/claimedAt/startedAt/finishedAt/result/failureCode=null; steps=[].

Transitions: pending→claimed before expiresAt; pending→expired at/after expiresAt; open commands claimed→opened/failed; computerUse claimed→running/failed and running→running/completed/failed. Claimant freezes after claim. Timestamps written by clients use serverTimestamp. Progress is at most 20 sequential `{index: 1-based integer, summary: 1–160 characters}` entries. Reporter commits in order, before the next action, using online transactions. No screenshots, absolute paths, or raw model errors in the command.

Completed result: `{fileName, previewText, previewTruncated}`. The Mac reads its exact prepared `.txt` file, rejects empty/whitespace-only content, and truncates the actual text to 8,000 Unicode scalars. The file stays on Mac. Filename contains no path separators.

Failure codes: setupIncomplete, noWorkspaceFolder, busy, unsupportedTarget, stoppedOnMac, runTimeout, modelUnavailable, actionFailed, noResultFile, quotaExceeded, serviceUnavailable, invalidModelAction, stepLimitExceeded, reportingUnavailable, documentChanged. Clients tolerate unknown codes without showing raw diagnostic output.

A local waiting warning at 20 seconds and an unconfirmed warning at reportingDeadline are not Firestore terminal statuses. Accept late receipts. Never replay a claimed task, including after restart or lost connectivity. The first opted-in Mac to claim wins. Turning off requests or changing account cancels active execution and fences late callbacks.

`computerUseStep` receives runId, commandId (null for local runs), stepIndex (0–19), taskSummary, screenshotBase64. Continuation IDs are private server-owned run metadata; the caller cannot supply them. A reserved uncertain step never issues another model request. Screenshots: PNG, ≤4 MiB, dimensions ≤2048; output ≤2048 tokens; upstream timeout 45 seconds. Run lifetime ≤180 seconds. Only type, editor keypress, wait, and finish are available.

`serviceControls/computerUse` is Admin-only and defaults OFF if absent. Set enabled=true only after signed receiver acceptance. Optional positive integer userDailyLimit/globalDailyLimit default to 200/2000 model calls per UTC day. New commands are limited to six per UID/minute; duplicate IDs bypass quota. These Mac-required beta callables intentionally do not enforce App Check. Auth and rules remain mandatory. Never use debug App Check tokens in Release.
