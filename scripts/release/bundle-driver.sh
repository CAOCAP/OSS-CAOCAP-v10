#!/bin/sh
set -eu
vendor="$SRCROOT/../vendor"
staged="$vendor/staged"
if [ ! -x "$staged/cua-driver" ]; then
  echo 'error: Bundled driver missing. Run python3 scripts/release/stage-driver.py from the repository root.' >&2
  exit 1
fi
expected=$(/usr/bin/plutil -extract sha256 raw -o - "$vendor/cua-driver.lock.json")
[ "$(cat "$staged/archive.sha256")" = "$expected" ] || { echo 'error: Staged driver lock mismatch.' >&2; exit 1; }
destination="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"
mkdir -p "$destination"
for name in cua-driver cua-cursor-theme; do
  binary_expected=$(/usr/bin/plutil -extract "binaries.$name" raw -o - "$vendor/cua-driver.lock.json")
  binary_actual=$(/usr/bin/shasum -a 256 "$staged/$name" | /usr/bin/awk '{print $1}')
  [ "$binary_actual" = "$binary_expected" ] || { echo "error: $name checksum mismatch." >&2; exit 1; }
  cp "$staged/$name" "$destination/$name"
  chmod 755 "$destination/$name"
  if [ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$destination/$name"
  fi
done
mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
cp "$vendor/LICENSE-cua.txt" "$vendor/cua-driver.lock.json" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/"
