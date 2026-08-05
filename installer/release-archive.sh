#!/usr/bin/env bash
#
# Fresh TestFlight archive helper for the Convene iPhone app.
#
# Archives the CURRENT source into a dated .xcarchive and prints the stamped version, build number,
# and export-compliance flag, so you can confirm it's genuinely new before distributing it. The
# failure this guards against is re-distributing a stale archive while Xcode auto-increments the
# build number: the number climbs, the code doesn't, and the fixes never reach TestFlight.
#
# Usage (run from anywhere):
#   installer/release-archive.sh          # archive at the current build number
#   installer/release-archive.sh --bump   # increment the build number first, then archive
#   installer/release-archive.sh --help
#
# After it finishes: Xcode > Window > Organizer, confirm the creation date is NOW, then
# Distribute App > App Store Connect with "Automatically manage version and build number"
# UNCHECKED, so it uploads exactly the build this printed.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: release-archive.sh [--bump | --help]

Create a fresh Release archive of the ConveneMobile target from the current source.

  --bump  Increment the iOS build number (CURRENT_PROJECT_VERSION) before archiving.
  --help  Show this help and exit without archiving.
EOF
}

bump=false
case "$#" in
  0) ;;
  1)
    case "$1" in
      --bump) bump=true ;;
      --help|-h) usage; exit 0 ;;
      *)
        echo "error: unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    ;;
  *)
    echo "error: expected at most one argument" >&2
    usage >&2
    exit 2
    ;;
esac

# Lets the argument handling be exercised without reading or mutating the project.
if [[ "${CONVENE_RELEASE_PARSE_ONLY:-0}" == "1" ]]; then
  $bump && echo "bump-and-archive" || echo "archive"
  exit 0
fi

cd "$(dirname "$0")/.." # -> repo root

SCHEME="ConveneMobile"
PROJECT_YML="project.yml"

# Unlike a checked-in .xcodeproj, the version lives in project.yml and xcodegen writes it into the
# generated project — so the bump edits the source of truth, not the build output.
#
# Reads a setting from under the ConveneMobile target, not the shared settings.base near the top of
# the file — hence the flag rather than an awk range: `  ConveneMobile:` matches a range's start and
# end pattern equally, which collapses it to a single line and finds nothing.
ios_setting() {
  awk -v key="$1:" '/^  ConveneMobile:/ { inTarget = 1 }
                    inTarget && $1 == key { gsub(/"/, "", $2); print $2; exit }' "$PROJECT_YML"
}

# The first match in the file, which is settings.base — it is declared above the targets.
base_setting() {
  awk -v key="$1:" '$1 == key { gsub(/"/, "", $2); print $2; exit }' "$PROJECT_YML"
}

# Deliberately no fallback: the build number must be the target's own, and --bump below rejects a
# project.yml where it is missing rather than silently climbing the shared one.
ios_build_number() {
  ios_setting CURRENT_PROJECT_VERSION
}

# The marketing version does fall back, since the target only overrides it while the two apps are on
# different numbers. Reading the base value unconditionally is what made this print the Mac app's
# version while stamping the iPhone app's into the binary.
marketing_version() {
  local version
  version="$(ios_setting MARKETING_VERSION)"
  [[ -n "$version" ]] || version="$(base_setting MARKETING_VERSION)"
  printf '%s' "$version"
}

if $bump; then
  cur="$(ios_build_number)"
  if [[ -z "$cur" ]]; then
    echo "error: could not find CURRENT_PROJECT_VERSION under the ConveneMobile target" >&2
    exit 1
  fi
  next=$((cur + 1))
  # Scoped to the ConveneMobile block so the Mac app's build number is left alone.
  perl -0pi -e "s/(  ConveneMobile:.*?CURRENT_PROJECT_VERSION: )\"${cur}\"/\${1}\"${next}\"/s" "$PROJECT_YML"
  echo "Bumped iOS build number: ${cur} -> ${next} (commit this)"
fi

VERSION="$(marketing_version)"
BUILD="$(ios_build_number)"
echo "==> Archiving Convene ${VERSION} (${BUILD}) from $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# The archive ships whatever is in the working tree — make uncommitted code loud.
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "WARNING: uncommitted changes in the working tree — they WILL be in this archive."
fi

xcodegen generate >/dev/null

ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
ARCHIVE="${ARCHIVE_DIR}/Convene ${VERSION} (${BUILD}) $(date +%H%M%S).xcarchive"
mkdir -p "$ARCHIVE_DIR"

xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

# Convene.app, not ConveneMobile.app: the target is ConveneMobile but PRODUCT_NAME is Convene.
PLIST="$ARCHIVE/Products/Applications/Convene.app/Info.plist"
read_key() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || echo MISSING; }

echo
echo "==> Archive created (also in Xcode Organizer):"
echo "    $ARCHIVE"
echo "    Bundle:     $(read_key CFBundleIdentifier)"
echo "    Version:    $(read_key CFBundleShortVersionString) ($(read_key CFBundleVersion))"
echo "    Encryption: ITSAppUsesNonExemptEncryption=$(read_key ITSAppUsesNonExemptEncryption)"
echo
echo "==> Next: Window > Organizer, confirm the creation date is NOW, then"
echo "    Distribute App > App Store Connect, with 'Automatically manage version"
echo "    and build number' UNCHECKED so it uploads exactly ${VERSION} (${BUILD})."
