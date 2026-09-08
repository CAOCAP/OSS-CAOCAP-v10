#!/bin/sh
set -eu
failed=0
require() { if [ -z "$2" ]; then echo "Missing: $1" >&2; failed=1; fi; }
require DEVELOPER_ID_APPLICATION "${DEVELOPER_ID_APPLICATION:-}"
require NOTARY_KEYCHAIN_PROFILE "${NOTARY_KEYCHAIN_PROFILE:-}"
require GITHUB_OAUTH_CLIENT_ID "${GITHUB_OAUTH_CLIENT_ID:-}"
require CAOCAP_RELEASE_STORE_OR_BUCKET "${CAOCAP_RELEASE_STORE:-${CAOCAP_RELEASE_BUCKET:-}}"
if ! security find-identity -v -p codesigning | grep -q 'Developer ID Application:'; then
  echo 'Missing: Developer ID Application certificate with private key in the login keychain.' >&2
  failed=1
fi
if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >/dev/null || failed=1
fi
exit "$failed"
