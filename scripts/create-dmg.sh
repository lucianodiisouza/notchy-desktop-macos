#!/usr/bin/env bash
#
# Build Notchy in Release, sign it with Developer ID, notarize it and wrap it in a notarized DMG.
# Usage: ./scripts/create-dmg.sh
#   The version comes from MARKETING_VERSION in the Xcode project. Output: build/Notchy-<version>.dmg
#
# Env (or .env.local at the repo root, which is git-ignored):
#   NOTCHY_SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#   NOTCHY_NOTARY_PROFILE  keychain profile from `xcrun notarytool store-credentials`
#
# Without NOTCHY_SIGN_IDENTITY the app is ad-hoc signed and Gatekeeper will block it on other Macs.
# Without NOTCHY_NOTARY_PROFILE it is signed but not notarized, and Gatekeeper still warns.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.local ]]; then
  # What the caller exported still wins over the file.
  ENV_BEFORE="$(export -p)"
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
  eval "$ENV_BEFORE" 2>/dev/null || true
fi

IDENTITY="${NOTCHY_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTCHY_NOTARY_PROFILE:-}"

APP_NAME="Notchy"
BUILD_DIR="build/dmg"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
ENTITLEMENTS="Notchy/Resources/Notchy.entitlements"
BG_IMAGE="scripts/dmg/background.tiff"

if ! command -v create-dmg &>/dev/null; then
  echo "Error: 'create-dmg' not found. Install it with:"
  echo "  brew install create-dmg"
  exit 1
fi

# ── 1. Build ────────────────────────────────────────────────────────────────
# Built ad-hoc, then signed below with the Developer ID, so Xcode's automatic signing never picks a development cert.
echo "-> Building ${APP_NAME} (Release, universal)..."
xcodebuild -project Notchy.xcodeproj -scheme Notchy \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -quiet clean build

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG="build/${APP_NAME}-${VERSION}.dmg"
echo "-> ${APP_NAME} ${VERSION}"

# ── 2. Sign + notarize the app ──────────────────────────────────────────────
if [[ -n "$IDENTITY" ]]; then
  echo "-> Signing with: $IDENTITY"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    "$APP_PATH"
  codesign --verify --strict --verbose=2 "$APP_PATH"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "-> Notarizing the app (usually a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$ZIP_PATH"
    xcrun stapler staple "$APP_PATH"
  else
    echo "   (NOTCHY_NOTARY_PROFILE not set, skipping notarization)"
  fi
else
  echo "   (NOTCHY_SIGN_IDENTITY not set, the app stays ad-hoc signed)"
fi

# ── 3. DMG ──────────────────────────────────────────────────────────────────
echo "-> Creating ${DMG}..."
rm -f "$DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_PATH" "$STAGING/${APP_NAME}.app"

DMG_SIGN_ARGS=()
[[ -n "$IDENTITY" ]] && DMG_SIGN_ARGS+=(--codesign "$IDENTITY")

create-dmg \
  --volname "$APP_NAME" \
  --background "$BG_IMAGE" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 96 \
  --icon "${APP_NAME}.app" 160 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 190 \
  ${DMG_SIGN_ARGS[@]+"${DMG_SIGN_ARGS[@]}"} \
  "$DMG" \
  "$STAGING/"

if [[ -n "$IDENTITY" && -n "$NOTARY_PROFILE" ]]; then
  echo "-> Notarizing the DMG..."
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"

  echo "-> Verifying..."
  xcrun stapler validate "$APP_PATH"
  xcrun stapler validate "$DMG"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

echo ""
echo "Done. DMG ready: $DMG"
