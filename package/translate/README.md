# Folder Popup translations

English is the source language and built-in fallback. Plasma automatically uses the Russian catalog when the desktop language is Russian (`ru`, including regional variants such as `ru_RU`). No widget setting is required.

- `ru.po` — editable Russian translations.
- `template.pot` — English source-string template.
- `../contents/locale/ru/LC_MESSAGES/plasma_applet_io.github.wadehusky.folderpopup.mo` — compiled catalog included in the plasmoid.

After editing `ru.po`, install GNU gettext and run `./build.sh` from this directory to rebuild the catalog.
