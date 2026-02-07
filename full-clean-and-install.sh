#!/bin/bash
# Full clean + reinstall do Notchy (limpa DerivedData, cache de ícone, e instala de novo)
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="Notchy"
PROJECT="Notchy.xcodeproj"
APP_NAME="Notchy.app"

echo "=== Encerrando Notchy se estiver aberto ==="
pkill -x "Notchy" 2>/dev/null || true
sleep 1

echo "=== Clean no Xcode ==="
cd "$PROJECT_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug clean -quiet

echo "=== Removendo DerivedData do Notchy ==="
DERIVED=~/Library/Developer/Xcode/DerivedData
if [ -d "$DERIVED" ]; then
  for dir in "$DERIVED"/Notchy-*; do
    if [ -d "$dir" ]; then
      rm -rf "$dir"
      echo "Removido: $dir"
    fi
  done
fi

echo "=== Removendo app antigo de /Applications (se existir) ==="
if [ -d "/Applications/$APP_NAME" ]; then
  rm -rf "/Applications/$APP_NAME"
  echo "Removido /Applications/$APP_NAME"
fi

echo "=== Build e instalação ==="
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug build -quiet

echo "=== Copiando app para /Applications ==="
BUILT_APP=$(find "$DERIVED" -name "$APP_NAME" -type d 2>/dev/null | head -1)
if [ -n "$BUILT_APP" ] && [ -d "$BUILT_APP" ]; then
  cp -R "$BUILT_APP" /Applications/
  echo "Instalado em /Applications/$APP_NAME"
else
  echo "App construído em DerivedData; abra o Xcode e rode com Cmd+R para instalar no destino padrão."
fi

echo "=== Limpando cache de ícones do macOS ==="
# Força o macOS a recarregar ícones
touch "/Applications/$APP_NAME" 2>/dev/null || true
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo ""
echo "Pronto. Abra o Notchy em /Applications (ou pelo Xcode)."
echo "Se o ícone ainda não atualizar, reinicie o Mac."
