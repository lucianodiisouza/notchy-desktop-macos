#!/bin/bash
# Cria um DMG para instalação dos dois apps: Notchy (Prompter) e Notchy Scripts.
# O usuário abre o DMG e arrasta os dois .app para a pasta Aplicativos.
#
# Uso: ./create-dmg.sh [VERSÃO]
#      Ex.: ./create-dmg.sh        → Notchy.dmg
#           ./create-dmg.sh 1.0.0  → Notchy-1.0.0.dmg

set -e

VERSION="${1:-}"
# Repo root (parent of scripts/), so the script works when run from repo root or CI
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="Notchy.xcodeproj"
SCHEME_MAIN="Notchy"
APP_PROMPTER="Notchy.app"
APP_SCRIPTS="Notchy Scripts.app"
DERIVED=~/Library/Developer/Xcode/DerivedData
VOLUME_NAME="Install Notchy"
DMG_NAME="Notchy"
[[ -n "$VERSION" ]] && DMG_NAME="Notchy-${VERSION}"
STAGING="$PROJECT_DIR/build-dmg-staging"
DMG_RW="$PROJECT_DIR/${DMG_NAME}-temp.dmg"
DMG_FINAL="$PROJECT_DIR/${DMG_NAME}.dmg"

echo "=== Criar DMG Notchy (Prompter + Scripts) ==="
echo "  Saída: $DMG_FINAL"
echo ""

# Build Release
echo "=== Build Release (os dois .app) ==="
cd "$PROJECT_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME_MAIN" -configuration Release build -quiet

echo "=== Localizando .app em DerivedData ==="
BUILD_ROOT=$(find "$DERIVED" -maxdepth 1 -type d -name "Notchy-*" 2>/dev/null | head -1)
if [[ -z "$BUILD_ROOT" ]]; then
  echo "Erro: pasta Notchy-* não encontrada em $DERIVED"
  exit 1
fi

APP_PROMPTER_PATH=$(find "$BUILD_ROOT" -name "$APP_PROMPTER" -type d 2>/dev/null | head -1)
APP_SCRIPTS_PATH=$(find "$BUILD_ROOT" -name "$APP_SCRIPTS" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PROMPTER_PATH" ]] || [[ ! -d "$APP_PROMPTER_PATH" ]]; then
  echo "Erro: $APP_PROMPTER não encontrado."
  exit 1
fi
if [[ -z "$APP_SCRIPTS_PATH" ]] || [[ ! -d "$APP_SCRIPTS_PATH" ]]; then
  echo "Erro: $APP_SCRIPTS não encontrado."
  exit 1
fi

# Staging: pasta com os dois apps + symlink para /Applications
echo "=== Montando pasta do DMG ==="
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PROMPTER_PATH" "$STAGING/"
cp -R "$APP_SCRIPTS_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Criar DMG read-write, montar, ajustar visualização, converter para read-only
echo "=== Criando DMG ==="
rm -f "$DMG_RW" "$DMG_FINAL"
MOUNTPOINT="$PROJECT_DIR/.dmg-mount"
rm -rf "$MOUNTPOINT" && mkdir -p "$MOUNTPOINT"

# Tamanho: espaço dos dois .app + folga (em MB). 100 MB é suficiente para dois apps pequenos.
SIZE_MB=100
hdiutil create -srcfolder "$STAGING" -volname "$VOLUME_NAME" -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${SIZE_MB}m" "$DMG_RW"

# Montar em pasta fixa para ajustar ícones (e opcionalmente layout do Finder)
hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" -mountpoint "$MOUNTPOINT" -quiet
echo "  Volume montado em: $MOUNTPOINT"

# Ajustar janela do Finder (skip em CI: AppleScript/Finder pode travar em runners headless)
if [[ -z "$CI" ]]; then
  osascript <<EOF
tell application "Finder"
  open POSIX file "$MOUNTPOINT"
  tell front window
    set current view to icon view
    set toolbar visible to false
    set statusbar visible to false
    set bounds to {100, 100, 700, 400}
    set position of item "Applications" to {400, 180}
    set position of item "$APP_PROMPTER" to {100, 180}
    set position of item "$APP_SCRIPTS" to {250, 180}
  end tell
  tell icon view options of front window
    set icon size to 72
    set text size to 12
    set arrangement to not arranged
  end tell
  update every item of front window
  close front window
end tell
EOF
else
  echo "  (CI: pulando layout do Finder)"
fi

# Desmontar
hdiutil detach "$MOUNTPOINT" -quiet
rmdir "$MOUNTPOINT" 2>/dev/null || true

# Converter para read-only comprimido (UDZO)
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" -quiet
rm -f "$DMG_RW"
rm -rf "$STAGING"

echo ""
echo "Pronto. DMG criado: $DMG_FINAL"
echo "  Abra o arquivo e arraste os dois apps para Aplicativos para instalar."
