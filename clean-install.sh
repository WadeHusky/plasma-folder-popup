#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ID='io.github.wadehusky.folderpopup'
ARCHIVE="$ROOT/io.github.wadehusky.folderpopup-1.0.0.plasmoid"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/plasma/plasmoids/$ID"

command -v kpackagetool6 >/dev/null 2>&1 || {
    echo 'Не найден kpackagetool6. Установите инструменты KDE Plasma 6.' >&2
    exit 1
}
command -v kreadconfig6 >/dev/null 2>&1 || {
    echo 'Предупреждение: kreadconfig6 не найден; подписи .desktop будут показываться как имена файлов.' >&2
}
[[ -f "$ARCHIVE" ]] || "$ROOT/build.sh"
kpackagetool6 --type Plasma/Applet --remove "$ID" >/dev/null 2>&1 || true
rm -rf -- "$INSTALL_DIR"
kpackagetool6 --type Plasma/Applet --install "$ARCHIVE"
MAIN_QML="$INSTALL_DIR/contents/ui/main.qml"
[[ -f "$MAIN_QML" ]] || { echo 'Не найден установленный main.qml.' >&2; exit 1; }
for expression in \
    'onRequestRename: root.scheduleRename()' \
    'target: folderModel.action("rename")' \
    'function onTriggered()' \
    'renameDialogComponent.createObject(popupView)' \
    'folderModel.rename(root.renameTargetRow, newName)' \
    'TapHandler {' \
    'gesturePolicy: TapHandler.WithinBounds' \
    'HoverHandler {' \
    'compactHover.hovered ? 0.13 : 0.0' \
    'onTapped: root.expanded = !root.expanded' \
    'folderModel.openContextMenu(fileDelegate, mouse.modifiers)';
do
    grep -Fq -- "$expression" "$MAIN_QML" || { echo "ОШИБКА: отсутствует $expression" >&2; exit 1; }
done
for forbidden in \
    'ContainmentLayoutManager.ItemContainer.AfterPress' \
    'function configureNativeAppletDrag()' \
    'Drag.active:' \
    'Drag.mimeData:' \
    'configOverlayVisible = false';
do
    if grep -Fq -- "$forbidden" "$MAIN_QML"; then
        echo "ОШИБКА: обнаружен нежелательный drag override: $forbidden" >&2
        exit 1
    fi
done
if grep -Fq -- 'fileGrid.itemAtIndex(row)' "$MAIN_QML"; then
    echo 'ОШИБКА: beginRename() не должен обращаться к fileGrid из области PlasmoidItem.' >&2
    exit 1
fi
printf '\nУстановлен Folder Popup 1.0.0. Перезапустите Plasma Shell.\n'
echo "Файл: $MAIN_QML"
