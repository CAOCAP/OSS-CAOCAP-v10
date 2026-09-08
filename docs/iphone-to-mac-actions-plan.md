# Expand iPhone-to-Mac actions

Status: proposed; implementation has not started.

## Goal and current state

The selected direction is to expand actions initiated from iPhone CoCaptain and performed by the user's signed-in Mac. The proposed next action is browser search. Example: “Search YouTube for beginner SwiftUI tutorials on my Mac.” The Mac opens the requested search in its default browser and iPhone chat reports the actual command receipt.

The repository already implements provider-linked device presence, callable command creation, a Mac opt-in, transactional command claiming, and browser opening for YouTube home/watch links and allowlisted documentation URLs. These are bounded commands, not a general computer-use runtime. This planning pass inspected source and existing tests; it did not verify deployed services or run the apps.

Two existing behaviors need correction alongside expansion: a 20-second timeout is presented as proof that Mac requests are disabled, and pending commands have no expiry. The iPhone client also has one mutable receipt/listener shared by requests, which must not associate one action's result with another.

References: [iOS behavior](../apps/ios/README.md), [Mac behavior](../apps/macos/README.md), and [product requirements](SRS.md). Mac-local AI chat and the Explore / Build / Collaborate experiences remain separate work.

## 1. Make command delivery and receipts dependable

- Give each request its own command ID and receipt lifecycle. Reuse a client-generated request ID when retrying an uncertain callable response; the server returns the existing command for the same request and rejects reuse with different content. Do not automatically resend an action whose execution outcome is unknown.
- Add server-authored creation and expiry times to newly created commands. Allow 60 seconds to claim a pending command. Check expiry in the claim transaction and enforce the deadline with Firestore rules using server time. Updated Macs must ignore legacy pending commands without an expiry. Deploy the updated Mac before issuing new commands.
- Keep pending → claimed → opened/failed. Allow expired pending commands to become expired. Do not reassign or replay a claimed command when an execution receipt is missing: the browser may already have opened.
- After 20 seconds without a terminal receipt, show “Your Mac has not confirmed this request yet.” This is a waiting timeout, not proof of disabled requests or failure. Preserve the command identity and accept a later receipt while its originating UI session is active. An expired request displays “Request expired. Try again.”
- Before claiming and immediately before opening, check that requests remain enabled and the signed-in account still matches the command. Ignore callbacks from a previous account or request. A cancelled iPhone wait must finish promptly; stopping the wait does not claim to undo an already dispatched Mac action.
- Restrict Firestore client updates to the fields needed for each permitted state transition. Command identity, action, arguments, creation time, and expiry remain immutable. Keep account ownership checks and server-only command creation.
- Preserve the existing first-enabled-Mac claim behavior for this slice; acceptance testing uses one opted-in Mac. Target selection and offline queuing are deferred.

## 2. Add search as one bounded action

- Add `search_on_mac` to the existing iOS action catalog, model function declaration, output handling, validation, and remote runner. Arguments are `provider` (`google` or `youtube`) and `query`. Agent mode may dispatch it; Ask and Plan remain prose-only.
- Add a `createSearchOnMac` callable returning `{ commandId }`. Its input is `{ requestId, provider, query }`. Trim query whitespace; reject empty input, unsupported providers, or more than 500 UTF-16 code units. Apply the same validation in iOS, the callable, and Mac.
- Persist `type: search`, provider, query, the server-built URL, request identity, and lifecycle fields in the existing per-user commands collection. Construct URLs with URL query APIs: `https://www.google.com/search?q=…` or `https://www.youtube.com/results?search_query=…`. The model supplies search text, not a destination URL. The Mac independently validates the fields and constructs the same allowed destination before opening it.
- Reuse the Mac relay and default-browser opening path. Keep browser opening outside the transaction callback, since Firestore can retry that callback. See [Firebase transaction guidance](https://firebase.google.com/docs/firestore/manage-data/transactions).
- Update model instructions so an explicit web or YouTube search uses this action. Opening a supplied supported link continues to use the existing open actions. A missing search topic prompts clarification. Default an unspecified search provider to Google.
- On a successful browser-open receipt, say “Opened YouTube search results for ‘…’ on your Mac” or the Google equivalent. Do not claim that a result was read, ranked, selected, or verified. Reading results and clicking through them require a later milestone.

## 3. Verify and release

- Add focused iOS tests for provider/query mapping, Unicode and reserved-character encoding, blank/oversized input, Agent versus Ask/Plan behavior, timeout copy, cancellation, late callbacks, and separate command receipts.
- Add a macOS test target for command validation and relay behavior using an injected clock and browser opener. Cover duplicate delivery, expiry, opt-out/account changes during a claim, opening failure, and missing completion receipts.
- Add backend validation/idempotency tests and Firestore emulator tests for account isolation, immutable fields, expiry at the boundary, and allowed state transitions. Keep existing YouTube and documentation tests passing.
- Build both apps with the full Xcode developer directory specified in repository guidance; run relevant tests, the functions TypeScript build, and `git diff --check`.
- In a signed development setup, try Google and YouTube queries from iPhone Agent chat with both apps on the same linked account. Verify the exact query in the Mac browser, one open per command, truthful receipts, opt-out, delayed reconnect beyond expiry, and unchanged Ask/Plan behavior. A build alone does not satisfy this check.
- Release the updated Mac receiver first, then the command functions/rules, then the iOS search action. Verify existing open commands at each step. Scope backend deployment to command functions and rules; the waitlist/hosting does not need redeployment. Update platform setup notes with observed validation and limitations.

## Assumptions and boundary

The user selected expansion of iPhone-to-Mac actions. Browser search is the recommended first addition, pending any different action preference; Google is the proposed web-search default. Use existing Firebase infrastructure and Mac opt-in. This slice adds no screen capture, Accessibility automation, document writing, arbitrary URL execution, new platforms, or Mac-local AI chat. Commit, push, and live deployment are separate from preparing this plan.
