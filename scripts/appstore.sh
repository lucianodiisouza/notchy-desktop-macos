#!/usr/bin/env bash
#
# Archive Notchy for the Mac App Store.
# Usage:
#   ./scripts/appstore.sh            archive and export a signed .pkg into build/appstore (nothing leaves this Mac)
#   ./scripts/appstore.sh --upload   archive and upload the build to App Store Connect
#
# The build is compiled with the APPSTORE condition, which drops the GitHub release check (the store delivers
# updates), and signed without the network entitlement it no longer needs. Signing is automatic through the Apple account signed in to Xcode (Settings > Accounts). The first run
# creates the Apple Distribution and Mac Installer Distribution certificates and the App Store profile if they are
# missing. The app record must already exist in App Store Connect before --upload.
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DESTINATION="export"
[[ "${1:-}" == "--upload" ]] && DESTINATION="upload"

OUT="build/appstore"
ARCHIVE="$OUT/Notchy.xcarchive"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "-> Archiving Notchy (Release, universal, APPSTORE)..."
xcodebuild -project Notchy.xcodeproj -scheme Notchy \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APPSTORE' \
  CODE_SIGN_ENTITLEMENTS=Notchy/Resources/Notchy-AppStore.entitlements \
  -quiet archive

# Same options file, with the destination this run asked for.
OPTIONS="$OUT/ExportOptions.plist"
cp appstore/ExportOptions.plist "$OPTIONS"
/usr/libexec/PlistBuddy -c "Set :destination $DESTINATION" "$OPTIONS"

echo "-> Exporting ($DESTINATION)..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OPTIONS" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist")"
if [[ "$DESTINATION" == "upload" ]]; then
  echo "Done. Notchy $VERSION ($BUILD) uploaded; it shows up in App Store Connect > TestFlight after processing."
else
  echo "Done. Notchy $VERSION ($BUILD): $OUT/Notchy.pkg"
fi
