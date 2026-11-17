#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$ROOT/package"
METADATA="$PACKAGE_DIR/metadata.json"

if [[ ! -f "$METADATA" ]]; then
    printf 'Не найден файл метаданных: %s\n' "$METADATA" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf 'Для чтения версии из metadata.json требуется python3.\n' >&2
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    printf 'Не найдена команда zip. Установите пакет zip.\n' >&2
    exit 1
fi

VERSION="$(python3 - "$METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    metadata = json.load(file)

version = metadata.get("KPlugin", {}).get("Version")
if not isinstance(version, str) or not version.strip():
    raise SystemExit("В metadata.json отсутствует KPlugin.Version")

print(version.strip())
PY
)"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    printf 'Некорректная версия в metadata.json: %s\n' "$VERSION" >&2
    exit 1
fi

OUTPUT="$ROOT/io.github.wadehusky.folderpopup-${VERSION}.plasmoid"

rm -f "$OUTPUT"

(
    cd "$PACKAGE_DIR"
    zip -qr "$OUTPUT" metadata.json contents
)

if command -v unzip >/dev/null 2>&1; then
    unzip -tq "$OUTPUT" >/dev/null
fi

printf 'Создан пакет: %s\n' "$OUTPUT"
