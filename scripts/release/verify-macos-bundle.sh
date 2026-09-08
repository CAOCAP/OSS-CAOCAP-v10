#!/bin/sh
# Asserts the macOS bundle's security invariants against a *signed* build.
#
# These cannot be checked any other way: CODE_SIGNING_ALLOWED=NO skips
# entitlement processing entirely, so an unsigned build embeds nothing and
# both the build and the tests pass no matter what the entitlements say.
#
# Usage: verify-macos-bundle.sh /path/to/caocap.app
set -eu

app=${1:?usage: verify-macos-bundle.sh <path to caocap.app>}
helper="$app/Contents/XPCServices/ComputerUseHelper.xpc"
driver="$helper/Contents/Helpers/cua-driver"
failed=0
fail() { echo "FAIL: $1" >&2; failed=1; }
ok() { echo "ok: $1"; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# plutil cannot reliably read a plist from a pipe, so dump to a file first.
entitlements() {
  out="$work/$(echo "$1" | /usr/bin/shasum | cut -c1-16).plist"
  [ -s "$out" ] || codesign -d --entitlements - --xml "$1" 2>/dev/null > "$out" || true
  echo "$out"
}
has_key() { /usr/libexec/PlistBuddy -c "Print :$2" "$(entitlements "$1")" 2>/dev/null; }
has_sandbox() { has_key "$1" com.apple.security.app-sandbox; }

# The app must stay sandboxed. It does the network I/O and parses model output,
# and the helper's XPC protocol is the only sanctioned route to event injection.
[ "$(has_sandbox "$app")" = "true" ] \
  && ok "app is sandboxed" \
  || fail "app is NOT sandboxed (expected com.apple.security.app-sandbox = true)"

for key in com.apple.security.files.user-selected.read-write com.apple.security.files.bookmarks.app-scope; do
  [ "$(has_key "$app" "$key")" = "true" ] \
    && ok "app has $key" \
    || fail "app is missing $key (the working folder cannot be chosen or restored)"
done

# The helper must NOT be sandboxed. A sandboxed process can never hold
# Accessibility, and it would pass its sandbox to the driver it spawns.
[ -d "$helper" ] || fail "helper is not embedded at $helper"
if [ "$(has_sandbox "$helper")" = "true" ]; then
  fail "helper IS sandboxed -- it can never be granted Accessibility"
else
  ok "helper is not sandboxed"
fi

# The helper spawns the driver from its own bundle, so it has to be there and
# be signed the same way -- Gatekeeper rejects the whole app otherwise.
[ -x "$driver" ] && ok "driver is bundled where the helper looks for it" \
  || fail "driver missing at $driver (helper resolves Bundle.main/Contents/Helpers/cua-driver)"
if [ -x "$driver" ]; then
  codesign --verify --strict "$driver" 2>/dev/null \
    && ok "driver signature is valid" \
    || fail "driver signature is invalid"
fi

codesign --verify --deep --strict "$app" 2>/dev/null \
  && ok "bundle passes deep signature verification" \
  || fail "bundle fails deep signature verification"

[ "$failed" -eq 0 ] && echo "All macOS bundle invariants hold." || echo "macOS bundle invariants violated." >&2
exit "$failed"
