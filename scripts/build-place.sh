#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT="${1:-build/ContrabandAirways.rbxlx}"

mkdir -p "$(dirname "$OUT")"

if command -v aftman >/dev/null 2>&1; then
  aftman install
  export PATH="$ROOT_DIR/.aftman/bin:$PATH"
fi

wally install
rojo build default.project.json -o "$OUT"

echo "Built place: $OUT"
