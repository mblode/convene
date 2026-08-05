#!/usr/bin/env bash
#
# Capture raw App Store screenshots from the seeded simulator build.
#
# Apple requires a 6.9" iPhone set, which is 1320x2868 — the native resolution of the iPhone 17 Pro
# Max simulator, so the captures need no rescaling.
#
# The seeded fixture lives behind `#if DEBUG` (ConveneMobile/Debug/ScreenshotFixture.swift), so this
# deliberately builds Debug. A Release build lands on WelcomeView with an empty library.
#
# Usage:
#   screenshots/capture.sh          # capture into screenshots/raw/
#   screenshots/capture.sh --keep   # also keep the .xcresult bundle
set -euo pipefail

cd "$(dirname "$0")/.."  # -> repo root

PROJECT="Convene.xcodeproj"
SCHEME="ConveneMobile"
BUNDLE_ID="co.blode.convene.mobile"
DEVICE_NAME="Convene AppStore 6.9"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
RAW_DIR="screenshots/raw"
RESULT_BUNDLE="screenshots/.capture.xcresult"

keep_bundle=false
if [[ "${1:-}" == "--keep" ]]; then
  keep_bundle=true
elif [[ $# -gt 0 ]]; then
  echo "error: unknown argument: $1" >&2
  exit 2
fi

# Convene.xcodeproj is generated and gitignored, so it may not exist yet.
if [[ ! -d "$PROJECT" ]]; then
  echo "==> Generating $PROJECT"
  xcodegen generate
fi

udid="$(xcrun simctl list devices -j | /usr/bin/python3 -c "
import json,sys
name = '$DEVICE_NAME'
data = json.load(sys.stdin)['devices']
for runtime, devices in data.items():
    for device in devices:
        if device['name'] == name and device.get('isAvailable'):
            print(device['udid'])
            raise SystemExit
")"

if [[ -z "$udid" ]]; then
  echo "==> Creating simulator '$DEVICE_NAME'"
  udid="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")"
fi
echo "==> Using simulator $DEVICE_NAME ($udid)"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b

# Marketing screenshots must not show a real clock or a half-empty battery.
xcrun simctl status_bar "$udid" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100

# Wipe the container first. The fixture writes each meeting under a stem built from its start date,
# so yesterday's run leaves markdown that today's seeding never overwrites — and the library reads
# every file it finds, duplicating the list.
xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true

rm -rf "$RESULT_BUNDLE" "$RAW_DIR"
mkdir -p "$RAW_DIR"

# Signed, unlike `make ios-build`/`ios-run`. An unsigned simulator build is refused by the Keychain
# (errSecMissingEntitlement), and the fixture stores its placeholder API keys there — without them
# Settings shows "Could not save the key to Keychain" in red, and the record button raises the
# add-a-key sheet instead of the recording sheet.
#
# UI tests are flaky in parallel, and these drive sheets and drags where a second clone of the app
# racing the same simulator is the difference between a screenshot and a blank frame.
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$udid" \
  -only-testing:'ConveneMobileUITests/ScreenshotCaptureTests' \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RESULT_BUNDLE"

# Screenshots ride out of the simulator as XCTest attachments; the result bundle is the only place
# they exist on the host.
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$RAW_DIR"

# Attachments are exported under generated names; manifest.json maps them back to the
# `attachment.name` each test set.
/usr/bin/python3 - "$RAW_DIR" <<'PY'
import json, pathlib, re, shutil, sys

raw = pathlib.Path(sys.argv[1])
manifest = json.loads((raw / "manifest.json").read_text())
renamed = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        suggested = attachment.get("suggestedHumanReadableName") or ""
        exported = raw / attachment["exportedFileName"]
        if not (suggested.endswith(".png") or exported.suffix == ".png"):
            continue
        # XCTest suffixes attachment names with "_<index>_<uuid>".
        stem = re.sub(r"_\d+_[0-9A-F-]{36}$", "", pathlib.Path(suggested).stem)
        shutil.move(exported, raw / f"{stem or exported.stem}.png")
        renamed += 1
print(f"exported {renamed} screenshots")
PY

find "$RAW_DIR" -type f ! -name '*.png' -delete
rmdir "$RAW_DIR"/*/ 2>/dev/null || true

if ! $keep_bundle; then
  rm -rf "$RESULT_BUNDLE"
fi

echo
echo "==> Raw screenshots in $RAW_DIR:"
for png in "$RAW_DIR"/*.png; do
  echo "    $(basename "$png") $(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ {printf "%s ", $2}')"
done
echo
echo "==> Next: node screenshots/compose.mjs"
