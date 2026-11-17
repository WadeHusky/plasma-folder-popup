import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // SimpleKCM provides the page's scrollable content area. Keep the vertical
    // scrollbar usable with a mouse and never allow a horizontal scrollbar.
    verticalScrollBarPolicy: QQC2.ScrollBar.AsNeeded
    verticalScrollBarInteractive: true
    horizontalScrollBarPolicy: QQC2.ScrollBar.AlwaysOff

    property alias cfg_folderUrl: folderField.text
    property alias cfg_compactWidthCells: compactWidth.value
    property alias cfg_compactHeightCells: compactHeight.value
    property alias cfg_iconSize: iconSize.value
    property alias cfg_maxItems: maxItems.value
    property alias cfg_sortReversed: reverseSort.checked
    property alias cfg_showHidden: showHidden.checked
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_compactPreview: compactPreview.checked
    property alias cfg_compactIcon: compactIcon.text
    property alias cfg_compactLabel: compactLabel.text

    property string cfg_sortField: "name"

    FolderDialog {
        id: folderDialog
        title: i18n("Select a folder for the widget")
        onAccepted: folderField.text = selectedFolder.toString()
    }

    Kirigami.FormLayout {
        id: formLayout

        // FormLayout automatically moves labels above controls when the page
        // becomes narrow, keeping the settings usable in compact dialogs.
        Flow {
            id: folderChooser
            Kirigami.FormData.label: i18n("Folder:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: folderField
                width: folderChooser.width >= browseButton.implicitWidth + Kirigami.Units.gridUnit * 15
                    ? folderChooser.width - browseButton.implicitWidth - folderChooser.spacing
                    : folderChooser.width
                placeholderText: "file:///home/user/Documents"
                selectByMouse: true
            }

            QQC2.Button {
                id: browseButton
                text: i18n("Browse…")
                icon.name: "folder-open"
                onClicked: folderDialog.open()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            text: i18n("Choose a local folder, or paste a file URL such as file:///home/user/Documents.")
            opacity: 0.75
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Icon size:")
            text: i18n("Compact view")
            font.bold: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Width × height (cells):")
            Layout.fillWidth: true
            Layout.minimumWidth: 0

            QQC2.SpinBox {
                id: compactWidth
                from: 1
                to: 4
                editable: true
                Layout.fillWidth: true
                Layout.minimumWidth: 64
            }
            QQC2.Label { text: "×" }
            QQC2.SpinBox {
                id: compactHeight
                from: 1
                to: 4
                editable: true
                Layout.fillWidth: true
                Layout.minimumWidth: 64
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Item icon size (px):")
            Layout.fillWidth: true
            Layout.minimumWidth: 0

            QQC2.SpinBox {
                id: iconSize
                from: 16
                to: 96
                stepSize: 4
                editable: true
                Layout.fillWidth: true
                Layout.minimumWidth: 64
                Layout.maximumWidth: 180
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Maximum items:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0

            QQC2.SpinBox {
                id: maxItems
                from: 1
                to: 500
                stepSize: 1
                editable: true
                Layout.fillWidth: true
                Layout.minimumWidth: 64
                Layout.maximumWidth: 180
            }
            Item { Layout.fillWidth: true }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: sortCombo
            Kirigami.FormData.label: i18n("Sort by:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            textRole: "label"
            valueRole: "value"
            model: [
                { "label": i18n("Name"), "value": "name" },
                { "label": i18n("Type"), "value": "type" },
                { "label": i18n("Modification date"), "value": "time" },
                { "label": i18n("Size"), "value": "size" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_sortField))
            onActivated: page.cfg_sortField = currentValue
        }

        QQC2.CheckBox {
            id: reverseSort
            text: i18n("Reverse order")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        QQC2.CheckBox {
            id: showHidden
            text: i18n("Show hidden files")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        QQC2.CheckBox {
            id: showLabels
            text: i18n("Show item labels")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: compactIcon
            Kirigami.FormData.label: i18n("Widget icon:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            placeholderText: "folder"
            selectByMouse: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            text: i18n("Enter an icon name from the installed icon theme (for example, folder, folder-documents, or drive-harddisk).")
            opacity: 0.75
        }

        QQC2.TextField {
            id: compactLabel
            Kirigami.FormData.label: i18n("Label below the icon:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            placeholderText: i18n("For example, Work or Projects")
            selectByMouse: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            text: i18n("When this field is empty, the selected folder's name is shown below the icon. You can change the label at any time.")
            opacity: 0.75
        }

        QQC2.CheckBox {
            id: compactPreview
            text: i18n("Show folder contents inside the icon (up to 4 items)")
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            text: i18n("In compact mode, the folder icon shows a small mosaic of the first four file, folder, and shortcut icons. For applications and web links, use .desktop files; the icon is taken from the Icon= entry.")
            opacity: 0.75
        }
    }

    Connections {
        target: page
        function onCfg_sortFieldChanged() {
            sortCombo.currentIndex = Math.max(0, sortCombo.indexOfValue(page.cfg_sortField))
        }
    }
}
