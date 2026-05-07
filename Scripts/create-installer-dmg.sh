#!/usr/bin/env bash
# create-installer-dmg.sh — DMG instalador com ícones grandes e atalho para Aplicações.
#
# Requisito (fora deste repo):
#   brew install create-dmg
#
# Fluxo típico (duas linhas — não colar sem espaço entre `release` e `./`):
#   ARCHES="arm64 x86_64" NOIZEE_SIGNING=adhoc ./Scripts/build-app.sh release
#   ./Scripts/create-installer-dmg.sh
#
# Opcional:
#   NOIZEE_DMG_BACKGROUND=/caminho/para/fundo.png  (recom.: ~660×400 px, igual à janela)
#   OUTPUT_PATH=~/Desktop/Noizee.dmg ./Scripts/create-installer-dmg.sh

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"

if ! command -v create-dmg &>/dev/null; then
  echo "create-dmg não encontrado." >&2
  echo "Instala com: brew install create-dmg" >&2
  exit 127
fi

APP_SRC="$ROOT/.build/app/Noizee.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "Falta $APP_SRC — corre primeiro ./Scripts/build-app.sh release" >&2
  exit 1
fi

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -a "$APP_SRC" "$STAGING/"

VOLNAME="Noizee ${MARKETING_VERSION}"

OUT="${OUTPUT_PATH:-}"
if [[ -z "$OUT" ]]; then
  mkdir -p "$ROOT/dist"
  OUT="$ROOT/dist/Noizee-${MARKETING_VERSION}-b${BUILD_NUMBER}.dmg"
fi

EXTRA_ARGS=( )
if [[ -n "${NOIZEE_DMG_BACKGROUND:-}" ]]; then
  if [[ -f "$NOIZEE_DMG_BACKGROUND" ]]; then
    EXTRA_ARGS+=(--background "$NOIZEE_DMG_BACKGROUND")
  else
    echo "WARN: NOIZEE_DMG_BACKGROUND definido mas ficheiro em falta: $NOIZEE_DMG_BACKGROUND" >&2
  fi
fi

echo "📀 A gerar instalador DMG → $OUT"
echo "   (atalho Applications + ícone da app grandes)"

# Ícones: esquerda = app (~176,192); direita = link para Aplicações (~448,192).
# window-size deve envolver ambos sem cortar (--icon-size até 128 no create-dmg).
# Bash 5.2 + set -u: array vazio em "${EXTRA_ARGS[@]}" dispara "unbound variable".
set +u
create-dmg \
  --volname "$VOLNAME" \
  --window-pos 200 120 \
  --window-size 660 420 \
  --icon-size 120 \
  --icon "Noizee.app" 176 205 \
  --hide-extension "Noizee.app" \
  --app-drop-link 448 205 \
  "${EXTRA_ARGS[@]}" \
  "$OUT" \
  "$STAGING"
set -u

echo "✅ Concluído: $OUT"
