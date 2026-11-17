#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
command -v msgfmt >/dev/null 2>&1 || { echo "gettext (msgfmt) is required to compile translations" >&2; exit 1; }
mkdir -p "$PACKAGE_DIR/contents/locale/ru/LC_MESSAGES"
msgfmt --check --check-format -o "$PACKAGE_DIR/contents/locale/ru/LC_MESSAGES/plasma_applet_io.github.wadehusky.folderpopup.mo" "$SCRIPT_DIR/ru.po"
