# Folder Popup — a popup folder widget for KDE Plasma 6

[English](README.md) | [Русский](README.ru.md)

**Folder Popup** is a KDE Plasma 6 desktop widget that represents a selected folder as a compact icon. Clicking the icon opens a popup panel with the folder contents. The widget uses KDE's built-in folder model, so file types, icons, launching items, and context actions are handled by Plasma and KIO.

## Features

### Compact representation

- A folder icon or a custom system icon.
- A label below the icon: a custom label or the name of the selected folder.
- A miniature preview showing up to four item icons.
- Hover highlighting that follows the active Kirigami theme.
- Open or close the popup with a short left-click.

### Popup panel

- A grid of files and folders with native KDE icons.
- Item names with wrapping and length limits.
- Navigation into subfolders and back to the previous folder.
- Opening files, applications, and web links through KDE/KIO.
- A button to open the current folder in the file manager.
- Automatic popup sizing: the panel fits the visible grid, uses up to four columns, and keeps a minimum width of two cells even when the folder contains only one item. The popup uses matching dynamic minimum and maximum size hints, so its window follows the calculated grid size even if Plasma has saved an older popup size.
- The grid becomes vertically scrollable when the contents exceed the available screen height.
- The native KDE context menu for individual files and folders.
- File and folder renaming through the context menu and the Folder Popup rename dialog.
- Loading, empty-folder, and unavailable-folder messages.
- Folder contents are updated by the KDE file model when the directory changes.

### `.desktop` files

Application launchers and web links use their system icons from `.desktop` files. Their displayed name is read from the `Name` key in the `[Desktop Entry]` group. KConfig resolves the locale-specific value when one is available, for example `Name[ru_RU]`. The widget reads the name with `kreadconfig6`; if the utility cannot be used or no name is returned, the filename is used as a fallback.

Example application launcher:

```ini
[Desktop Entry]
Type=Application
Name=Firefox
Name[ru_RU]=Firefox
Exec=firefox %u
Icon=firefox
Terminal=false
```

Example web link:

```ini
[Desktop Entry]
Type=Link
Name=My website
URL=https://example.org/
Icon=internet-web-browser
```

Folder Popup displays the launcher's icon and name. KDE handles launching the item; the widget does not use the `Exec` value to read its label.

## Settings

The widget settings let you configure:

- the folder to display;
- the compact icon's width and height;
- the item icon size;
- the maximum number of displayed items;
- sorting by name, type, modification date, or size;
- reverse sort order;
- whether hidden files are shown;
- whether item labels are shown;
- the system icon name for the compact widget;
- a custom label below the icon;
- whether the compact folder preview is enabled.

The compact representation defaults to 1×1 cells and can be resized in the settings. The popup panel automatically sizes itself to the visible contents: it uses up to four columns, keeps a minimum width of two cells for the header controls and item counter, and adjusts its height to the required number of rows. On tall folders, the grid is limited to a comfortable portion of the screen and can be scrolled. The default maximum number of displayed items is 64.

## Localization

The widget's interface uses **English as its source language and fallback**. When the Plasma desktop language is Russian (`ru`, including regional variants such as `ru_RU`), the built-in Russian translation is selected automatically. No language setting in the widget is required.

- `translate/ru.po` — editable Russian translation.
- `translate/template.pot` — template of the English source strings.
- `contents/locale/ru/LC_MESSAGES/plasma_applet_io.github.wadehusky.folderpopup.mo` — compiled Russian catalog included in the package.

After editing `ru.po`, rebuild the catalog with GNU gettext (`msgfmt`):

```bash
sh translate/build.sh
```

Then rebuild the widget package so the updated catalog is included.

## Requirements

- KDE Plasma 6.
- Qt 6 and Qt Quick, Qt Quick Controls, Qt Quick Dialogs, and Qt Quick Layouts.
- Kirigami and Plasma modules, including Plasma5Support.
- Plasma's internal folder model: `org.kde.private.desktopcontainment.folder`.
- `kpackagetool6` to install and remove the widget.
- `kreadconfig6` to read localized `Name` values from `.desktop` files. If it is unavailable, the widget falls back to the filename.
- `zip` to build the package from the source repository.
- GNU gettext (`msgfmt`) to rebuild the Russian translation catalog.

The widget targets Plasma 6. The model `org.kde.private.desktopcontainment.folder` is an internal Plasma API, so compatibility with future Plasma releases may require updates.

## Install from the source repository

Unpack or clone the source repository and open its root directory. Run:

```bash
./build.sh
./clean-install.sh
```

The installation script removes the previously installed copy of Folder Popup, installs the newly built package, and checks for the main QML files. It requires `kpackagetool6`.

After installation, restart Plasma Shell:

```bash
kquitapp6 plasmashell
kstart plasmashell
```

Alternatively, sign out of KDE and sign in again.

## Install a prebuilt package

If you already have a `.plasmoid` package, install it with:

```bash
kpackagetool6 --type Plasma/Applet --install /path/to/io.github.wadehusky.folderpopup-X.X.X.plasmoid
```

Then restart Plasma Shell or sign in again. Add Folder Popup to the desktop through Plasma's desktop edit mode and select the folder you want to display.

## First launch and configuration

1. Add Folder Popup to the Plasma desktop.
2. Open the widget settings.
3. Select a folder with the Browse button or enter a URL such as `file:///home/user/Documents`.
4. Configure the compact icon size, item icon size, labels, and sorting. The popup panel sizes itself automatically.
5. Optionally set a custom label and a system icon name.
6. Enable or disable the compact folder preview.
7. Click the compact icon to open the folder contents.

A short left-click opens or closes the popup.

## Troubleshooting

Follow Plasma and QML messages with:

```bash
journalctl --user -f -o cat | grep --line-buffered -Ei 'Folder Popup|folderpopup|plasmashell|QML|FolderModel'
```

If a `.desktop` launcher is displayed using its filename, check whether `kreadconfig6` is installed:

```bash
command -v kreadconfig6
```

Make sure the launcher contains the `[Desktop Entry]` group and a `Name=` key. To provide a Russian launcher name, add `Name[ru_RU]=...`.

If the folder does not open, check its URL/path and access permissions. See `journalctl` output for file-model errors.

## Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove io.github.wadehusky.folderpopup
```

If package files remain after removal, delete the local package directory:

```bash
rm -rf ~/.local/share/plasma/plasmoids/io.github.wadehusky.folderpopup
```

Restart Plasma Shell or sign out and sign in again after uninstalling.

## Project structure

```text
project/
├── package/
│   ├── metadata.json
│   ├── contents/
│   │   ├── config/
│   │   │   ├── config.qml
│   │   │   └── main.xml
│   │   ├── locale/
│   │   │   └── ru/LC_MESSAGES/
│   │   │       └── plasma_applet_io.github.wadehusky.folderpopup.mo
│   │   └── ui/
│   │       ├── configGeneral.qml
│   │       └── main.qml
│   └── translate/
│       ├── ru.po
│       ├── template.pot
│       ├── README.md
│       └── build.sh
├── build.sh
├── clean-install.sh
├── LICENSE
├── README.md
└── README.ru.md
```

## License

GPL-3.0-or-later. See the `LICENSE` file for the full license text.
