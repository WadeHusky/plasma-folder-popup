#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT/package"
OUTPUT="$ROOT/io.github.wadehusky.folderpopup-1.0.0.plasmoid"
rm -f "$OUTPUT"
zip -qr "$OUTPUT" metadata.json contents
printf 'Создан: %s\n' "$OUTPUT"
