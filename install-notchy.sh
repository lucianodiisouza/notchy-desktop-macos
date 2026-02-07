#!/bin/bash
# Instalador Notchy: compila e instala Notchy (Prompter) e Notchy Scripts em /Applications.
# Uso: ./install-notchy.sh [--release]
#      --release  usa configuração Release em vez de Debug

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="Notchy.xcodeproj"
SCHEME_MAIN="Notchy"
APP_PROMPTER="Notchy.app"
APP_SCRIPTS="Notchy Scripts.app"
DERIVED=~/Library/Developer/Xcode/DerivedData

CONFIG="Debug"
if [[ "${1:-}" == "--release" ]]; then
  CONFIG="Release"
fi

echo "=== Instalador Notchy ==="
echo "  Apps: Notchy (Prompter) + Notchy Scripts"
echo "  Configuração: $CONFIG"
echo ""

echo "=== Encerrando apps se estiverem abertos ==="
pkill -x "Notchy" 2>/dev/null || true
pkill -x "Notchy Scripts" 2>/dev/null || true
sleep 1

echo "=== Build (scheme $SCHEME_MAIN — gera os dois .app) ==="
cd "$PROJECT_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME_MAIN" -configuration "$CONFIG" build -quiet

echo "=== Procurando .app em DerivedData ==="
BUILD_ROOT=$(find "$DERIVED" -maxdepth 1 -type d -name "Notchy-*" 2>/dev/null | head -1)
if [[ -z "$BUILD_ROOT" ]]; then
  echo "Erro: pasta Notchy-* não encontrada em $DERIVED"
  exit 1
fi

APP_PROMPTER_PATH=$(find "$BUILD_ROOT" -name "$APP_PROMPTER" -type d 2>/dev/null | head -1)
APP_SCRIPTS_PATH=$(find "$BUILD_ROOT" -name "$APP_SCRIPTS" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PROMPTER_PATH" ]] || [[ ! -d "$APP_PROMPTER_PATH" ]]; then
  echo "Erro: $APP_PROMPTER não encontrado em $BUILD_ROOT"
  exit 1
fi
if [[ -z "$APP_SCRIPTS_PATH" ]] || [[ ! -d "$APP_SCRIPTS_PATH" ]]; then
  echo "Erro: $APP_SCRIPTS não encontrado em $BUILD_ROOT"
  exit 1
fi

echo "=== Instalando em /Applications ==="
# Prompter
if [[ -d "/Applications/$APP_PROMPTER" ]]; then
  rm -rf "/Applications/$APP_PROMPTER"
fi
cp -R "$APP_PROMPTER_PATH" /Applications/
echo "  Instalado: /Applications/$APP_PROMPTER (Notchy Prompter)"

# Scripts (app standalone)
if [[ -d "/Applications/$APP_SCRIPTS" ]]; then
  rm -rf "/Applications/$APP_SCRIPTS"
fi
cp -R "$APP_SCRIPTS_PATH" /Applications/
echo "  Instalado: /Applications/$APP_SCRIPTS (Notchy Scripts)"

echo "=== Atualizando ícones (Finder/Dock) ==="
touch "/Applications/$APP_PROMPTER" "/Applications/$APP_SCRIPTS" 2>/dev/null || true
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo ""
echo "Pronto. Instalados:"
echo "  • /Applications/$APP_PROMPTER  — Notchy Prompter (teleprompter / menu bar)"
echo "  • /Applications/$APP_SCRIPTS  — Notchy Scripts (editor de scripts)"
echo ""
echo "Abra pelo Spotlight ou em /Applications."
