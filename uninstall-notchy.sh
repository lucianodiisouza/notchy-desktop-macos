#!/bin/bash
# Remove o Notchy completamente do Mac (para testar install manual do zero).
# Uso: ./uninstall-notchy.sh

set -e

echo "=== Encerrando Notchy e Notchy Scripts ==="
pkill -x "Notchy" 2>/dev/null || true
pkill -x "Notchy Scripts" 2>/dev/null || true
sleep 1

echo "=== Removendo apps de /Applications ==="
rm -rf "/Applications/Notchy.app"
echo "  Removido /Applications/Notchy.app"
rm -rf "/Applications/Notchy Scripts.app"
echo "  Removido /Applications/Notchy Scripts.app"

echo "=== Removendo preferências (UserDefaults) ==="
rm -f "$HOME/Library/Preferences/com.notchy.app.plist"
rm -f "$HOME/Library/Preferences/dev.oprimo.notchy.plist"
rm -f "$HOME/Library/Preferences/com.notchy.scripts.plist"
echo "  Preferences limpas"

echo "=== Removendo App Group (scripts e dados compartilhados) ==="
rm -rf "$HOME/Library/Group Containers/group.com.notchy"
echo "  Group Containers/group.com.notchy removido"

echo "=== Removendo caches ==="
rm -rf "$HOME/Library/Caches/com.notchy.app"
rm -rf "$HOME/Library/Caches/dev.oprimo.notchy"
rm -rf "$HOME/Library/Caches/com.notchy.scripts"
echo "  Caches removidos"

echo "=== Removendo Saved Application State ==="
rm -rf "$HOME/Library/Saved Application State/com.notchy.app.savedState"
rm -rf "$HOME/Library/Saved Application State/com.notchy.scripts.savedState"
echo "  Saved state removido"

echo "=== Removendo Application Support (se existir) ==="
rm -rf "$HOME/Library/Application Support/Notchy"
rm -rf "$HOME/Library/Application Support/com.notchy.app"
rm -rf "$HOME/Library/Application Support/com.notchy.scripts"
echo "  Application Support limpo"

echo "=== Opcional: DerivedData do Notchy (para build limpo) ==="
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED" ]; then
  for dir in "$DERIVED"/Notchy-*; do
    if [ -d "$dir" ]; then
      rm -rf "$dir"
      echo "  Removido: $dir"
    fi
  done
fi

echo ""
echo "Notchy removido por completo. Pode testar o install manual agora."
