#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
"$root/scripts/release/preflight.sh"
python3 "$root/scripts/release/stage-driver.py"
out="$root/release-artifacts"
mkdir -p "$out"
archive="$out/caocap.xcarchive"
xcodebuild -project "$root/apps/macos/caocap/caocap.xcodeproj" -scheme caocap -configuration Release -destination 'generic/platform=macOS' -archivePath "$archive" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" GITHUB_OAUTH_CLIENT_ID="$GITHUB_OAUTH_CLIENT_ID" archive
app="$archive/Products/Applications/caocap.app"
helper="$app/Contents/XPCServices/ComputerUseHelper.xpc"
for binary in "$helper/Contents/Helpers/cua-driver" "$helper/Contents/Helpers/cua-cursor-theme"; do
  codesign --verify --strict "$binary"
done
codesign --verify --strict "$helper"
codesign --verify --deep --strict "$app"
# Asserts the sandbox/helper/driver invariants. A release that gets these wrong
# still builds, still passes tests, and simply cannot drive anything.
"$root/scripts/release/verify-macos-bundle.sh" "$app"
# Inspect intended entitlements, including the unsandboxed XPC service and main app scope.
codesign -d --entitlements - --xml "$app" > "$out/app-entitlements.plist"
codesign -d --entitlements - --xml "$helper" > "$out/helper-entitlements.plist"
/usr/bin/ditto -c -k --keepParent "$app" "$out/caocap-notarization.zip"
xcrun notarytool submit "$out/caocap-notarization.zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
name="CAOCAP-$version-$build.dmg"
[ ! -e "$out/$name" ] || { echo 'Refusing to replace an immutable DMG. Increase the build number.' >&2; exit 1; }
contents=$(mktemp -d)
trap 'rm -rf "$contents"' EXIT
/usr/bin/ditto "$app" "$contents/caocap.app"
ln -s /Applications "$contents/Applications"
hdiutil create -volname CAOCAP -srcfolder "$contents" -ov -format UDZO "$out/$name"
codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$out/$name"
xcrun notarytool submit "$out/$name" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$out/$name"
xcrun stapler validate "$out/$name"
shasum -a 256 "$out/$name"
stat -f '%z bytes' "$out/$name"
echo 'Keep this immutable artifact in private release storage. Complete clean-Mac acceptance before updating public-release.json.'
