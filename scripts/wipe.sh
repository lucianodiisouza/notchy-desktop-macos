#!/usr/bin/env bash
#
# Completely remove Notchy from this Mac: the running process, built products, settings, scripts, and any installed
# copy, including the separate "Notchy Scripts" app of versions before 1.0. Source code in this repo is NOT touched.
#
# Usage: ./scripts/wipe.sh [-y]   (-y skips the confirmation prompt)
#
set -euo pipefail

BUNDLE_ID="dev.oprimo.notchyPrompter"
OLD_BUNDLE_IDS=("dev.oprimo.notchyScripts" "com.notchy.app" "com.notchy.scripts" "dev.oprimo.notchy")
GROUP_ID="TJ7XUV6VQ9.com.notchy"
APP_NAME="Notchy"

if [[ "${1:-}" != "-y" ]]; then
  read -r -p "This deletes ${APP_NAME}, its settings AND ALL YOUR SCRIPTS. Continue? [y/N] " ans
  [[ "${ans}" == "y" || "${ans}" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

echo "-> Quitting ${APP_NAME}..."
pkill -x "${APP_NAME}" 2>/dev/null || true
pkill -x "Notchy Scripts" 2>/dev/null || true
sleep 0.5

echo "-> Removing built products from DerivedData..."
find "${HOME}/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d \
  -name "${APP_NAME}-*" -exec rm -rf {} + 2>/dev/null || true

echo "-> Removing installed copies..."
for dir in /Applications "${HOME}/Applications"; do
  rm -rf "${dir}/${APP_NAME}.app" "${dir}/Notchy Scripts.app" 2>/dev/null || true
done

echo "-> Removing the sandbox container (settings) and the scripts..."
rm -rf "${HOME}/Library/Containers/${BUNDLE_ID}" 2>/dev/null || true
rm -rf "${HOME}/Library/Group Containers/${GROUP_ID}" 2>/dev/null || true

echo "-> Removing preferences from before the sandbox..."
for id in "${BUNDLE_ID}" "${OLD_BUNDLE_IDS[@]}"; do
  defaults delete "${id}" 2>/dev/null || true
  rm -f "${HOME}/Library/Preferences/${id}.plist" 2>/dev/null || true
  rm -rf "${HOME}/Library/Caches/${id}" "${HOME}/Library/Saved Application State/${id}.savedState" 2>/dev/null || true
done

echo "-> Resetting the microphone and speech recognition permissions..."
tccutil reset Microphone "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset SpeechRecognition "${BUNDLE_ID}" 2>/dev/null || true

echo "-> Unregistering from Launch Services..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[[ -x "${LSREGISTER}" ]] && "${LSREGISTER}" -kill -r -domain local -domain user 2>/dev/null || true

echo "OK: ${APP_NAME} wiped from this Mac."
