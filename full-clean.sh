#!/bin/bash
# Full clean do Notchy (encerra app, clean no Xcode, remove DerivedData). Sem build nem instalação.
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="Notchy"
PROJECT="Notchy.xcodeproj"

echo "=== Encerrando Notchy se estiver aberto ==="
pkill -x "Notchy" 2>/dev/null || true
pkill -x "Notchy Scripts" 2>/dev/null || true
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

echo ""
echo "Pronto. Limpeza concluída. Rode o build no Xcode (Cmd+B) ou use full-clean-and-install.sh para instalar em /Applications."
