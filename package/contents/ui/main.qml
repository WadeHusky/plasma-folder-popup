import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.private.desktopcontainment.folder as Folder

PlasmoidItem {
    id: root

    // The compact representation remains on the desktop; Plasma owns the
    // anchored fullRepresentation popup and its native open/close animation.
    property int unit: Kirigami.Units.gridUnit * 4
    property int iconSize: Math.max(16, Math.min(96, Math.round(Number(plasmoid.configuration.iconSize) || 32)))
    property int gridCellExtent: Math.max(unit, iconSize + (showLabels
        ? Math.ceil(itemLabelMetrics.height * 2 + Kirigami.Units.smallSpacing * 4)
        : Kirigami.Units.smallSpacing * 2))
    property int compactWidthCells: Math.max(1, Math.min(4, Math.round(Number(plasmoid.configuration.compactWidthCells) || 1)))
    property int compactHeightCells: Math.max(1, Math.min(4, Math.round(Number(plasmoid.configuration.compactHeightCells) || 1)))
    property int compactWidth: compactWidthCells * gridCellExtent
    property int compactHeight: compactHeightCells * gridCellExtent
    property int maxItems: Math.max(1, Math.min(500, Math.round(Number(plasmoid.configuration.maxItems) || 64)))

    // The expanded popup sizes itself to the visible grid. It uses up to four
    // columns, reducing the column count when a folder contains fewer items.
    // Empty/loading states keep a three-cell width so their guidance remains legible.
    property int panelItemCount: Math.max(0, Math.min(folderCountModel.count, maxItems))
    property int gridColumns: panelItemCount > 0 ? Math.min(4, panelItemCount) : 3
    property int gridRows: panelItemCount > 0 ? Math.ceil(panelItemCount / gridColumns) : 2
    property int popupPadding: Kirigami.Units.smallSpacing
    property int popupSpacing: Kirigami.Units.smallSpacing
    property int popupHeaderHeight: Math.max(Kirigami.Units.iconSizes.medium, Kirigami.Units.gridUnit * 2)
    property int popupFooterHeight: panelItemCount > 0 ? Kirigami.Units.gridUnit : 0
    property int popupChromeHeight: popupHeaderHeight + popupFooterHeight
                                      + popupSpacing * 2 + popupPadding * 2
    property int panelWidth: gridColumns * gridCellExtent + popupPadding * 2
    property int naturalPanelHeight: gridRows * gridCellExtent + popupChromeHeight
    property int maximumPanelHeight: Math.max(gridCellExtent + popupChromeHeight,
                                               Math.floor(Screen.height * 0.75))
    property int panelHeight: Math.min(naturalPanelHeight, maximumPanelHeight)
    property bool showLabels: plasmoid.configuration.showLabels !== false
    property bool showHidden: plasmoid.configuration.showHidden === true
    property bool showPreview: plasmoid.configuration.compactPreview === true
    property string baseFolderUrl: String(plasmoid.configuration.folderUrl || "")
    property string compactIconName: String(plasmoid.configuration.compactIcon || "folder").trim() || "folder"
    property string compactLabelOverride: String(plasmoid.configuration.compactLabel || "").trim()
    property string compactLabelText: compactLabelOverride.length > 0 ? compactLabelOverride : folderTitle(baseFolderUrl)
    property string currentFolderUrl: ""
    property var pathStack: []
    // Cache and queue use arrays of fixed-shape records rather than long-lived
    // objects with dynamically added/removed keys. Only one local config query
    // runs at a time, avoiding a burst of child processes in large folders.
    property var desktopEntryNameCache: []
    property var desktopNameQueue: []
    property string activeDesktopNameCommand: ""
    property string activeDesktopNamePath: ""
    property int activeDesktopNameGeneration: -1
    property int desktopNameGeneration: 0
    // The native FolderModel context menu emits requestRename; the Plasmoid
    // supplies the matching inline-style dialog and calls FolderModel.rename().
    property int renameTargetRow: -1
    property string renameInitialName: ""
    property int renameSelectionBoundary: -1
    property var renameTargetUrl: null
    // The rename editor lives inside fullRepresentation so it belongs to the
    // popup window, not the compact applet window. This avoids deactivation
    // races when KDE's native QMenu closes after choosing Rename.
    property var renameDialogObject: null
    property bool renameDialogOpen: false
    property bool renameRequestPending: false
    property bool renameOpenQueued: false
    signal openRenameDialogRequested()

    TextMetrics {
        id: itemLabelMetrics
        font: Kirigami.Theme.defaultFont
        text: "Ag"
    }

    QQC2.Action {
        id: chooseFolderAction
        text: i18n("Choose folder…")
        icon.name: "folder-open"
        onTriggered: folderPicker.open()
    }

    implicitWidth: compactWidth
    implicitHeight: compactHeight
    switchWidth: 100000
    switchHeight: 100000
    // Keep the fullRepresentation alive while its inline rename editor is open.
    hideOnWindowDeactivate: !renameDialogOpen

    Plasmoid.title: i18n("Folder Popup")
    Plasmoid.icon: root.compactIconName
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: root.compactLabelText.length > 0
                     ? root.compactLabelText : root.folderTitle(root.baseFolderUrl)
    toolTipSubText: root.baseFolderUrl.length > 0
                    ? i18n("Open folder contents")
                    : i18n("Select a folder first")

    function folderTitle(url) {
        if (!url || String(url).length === 0) {
            return i18n("No folder selected")
        }
        var path = String(url).split(/[?#]/)[0]
        var parts = path.split("/")
        var lastPart = parts[parts.length - 1] || parts[parts.length - 2] || path
        try {
            return decodeURIComponent(lastPart)
        } catch (error) {
            return lastPart
        }
    }

    function enterFolder(row) {
        var nextStack = pathStack.slice(0)
        nextStack.push(folderModel.url)
        pathStack = nextStack
        folderModel.cd(row)
    }

    function goBack() {
        if (pathStack.length === 0) {
            return
        }
        var nextStack = pathStack.slice(0)
        var previousUrl = nextStack.pop()
        pathStack = nextStack
        folderModel.url = previousUrl
    }

    function openCurrentFolder() {
        if (folderModel.url && String(folderModel.url).length > 0) {
            Qt.openUrlExternally(folderModel.url)
        }
    }

    function openBaseFolder() {
        if (baseFolderUrl.length > 0) {
            Qt.openUrlExternally(baseFolderUrl)
        }
    }

    function openItem(row, isDirectory) {
        if (isDirectory) {
            enterFolder(row)
        } else {
            // KIO uses KDE's MIME associations and correctly handles .desktop
            // application launchers and Type=Link web shortcuts.
            folderModel.run(row)
        }
    }

    function localPathForUrl(fileUrl) {
        if (!fileUrl) {
            return ""
        }
        try {
            if (typeof fileUrl.toLocalFile === "function") {
                return String(fileUrl.toLocalFile())
            }
        } catch (error) {
            // Fall through to the conservative file:// parser below.
        }
        var textUrl = String(fileUrl)
        if (textUrl.indexOf("file://") !== 0) {
            return ""
        }
        var encodedPath = textUrl.substring(7)
        try {
            return decodeURIComponent(encodedPath)
        } catch (error) {
            return encodedPath
        }
    }

    function shellQuote(value) {
        // DataEngine's executable source receives a shell command. Quote the
        // filename as one argument even if it contains spaces or apostrophes.
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function cachedDesktopEntryName(localPath) {
        for (var i = 0; i < desktopEntryNameCache.length; ++i) {
            var entry = desktopEntryNameCache[i]
            if (entry.path === localPath) {
                return entry.name
            }
        }
        return ""
    }

    function startNextDesktopNameRequest() {
        if (activeDesktopNameCommand.length > 0 || desktopNameQueue.length === 0) {
            return
        }

        var nextQueue = desktopNameQueue.slice(0)
        var request = nextQueue.shift()
        desktopNameQueue = nextQueue

        activeDesktopNameCommand = request.command
        activeDesktopNamePath = request.path
        activeDesktopNameGeneration = request.generation
        desktopEntryReader.connectSource(request.command)
    }

    function requestDesktopEntryName(fileUrl, forceRefresh) {
        var localPath = localPathForUrl(fileUrl)
        if (!localPath || localPath.charAt(0) !== "/" || !/\.desktop$/i.test(localPath)) {
            return
        }

        if (activeDesktopNamePath === localPath
            && activeDesktopNameGeneration === desktopNameGeneration) {
            return
        }

        for (var i = 0; i < desktopNameQueue.length; ++i) {
            if (desktopNameQueue[i].path === localPath
                && desktopNameQueue[i].generation === desktopNameGeneration) {
                return
            }
        }

        if (!forceRefresh && cachedDesktopEntryName(localPath).length > 0) {
            return
        }

        if (forceRefresh) {
            var retainedCache = []
            for (var cacheIndex = 0; cacheIndex < desktopEntryNameCache.length; ++cacheIndex) {
                if (desktopEntryNameCache[cacheIndex].path !== localPath) {
                    retainedCache.push(desktopEntryNameCache[cacheIndex])
                }
            }
            desktopEntryNameCache = retainedCache
        }

        // kreadconfig6 reads the [Desktop Entry] group and resolves the
        // locale-specific Name[xx_YY] variant. The quoted path is the only
        // variable part of this fixed, read-only command.
        var command = "/usr/bin/kreadconfig6 --file " + shellQuote(localPath)
                   + " --group 'Desktop Entry' --key Name"
        var nextQueue = desktopNameQueue.slice(0)
        nextQueue.push({
            command: command,
            path: localPath,
            generation: desktopNameGeneration
        })
        desktopNameQueue = nextQueue
        startNextDesktopNameRequest()
    }

    function finishDesktopEntryNameRequest(command, result) {
        if (command !== activeDesktopNameCommand) {
            desktopEntryReader.disconnectSource(command)
            return
        }

        var localPath = activeDesktopNamePath
        var requestGeneration = activeDesktopNameGeneration

        // A folder change invalidates queued requests. An already-running
        // process is allowed to finish, but its stale result is never cached.
        if (requestGeneration === desktopNameGeneration && Number(result["exit code"]) === 0) {
            var name = String(result.stdout || "").replace(/[\r\n]+$/, "")
            if (name.length > 0) {
                var nextCache = []
                for (var cacheIndex = 0; cacheIndex < desktopEntryNameCache.length; ++cacheIndex) {
                    if (desktopEntryNameCache[cacheIndex].path !== localPath) {
                        nextCache.push(desktopEntryNameCache[cacheIndex])
                    }
                }
                nextCache.push({ path: localPath, name: name })
                desktopEntryNameCache = nextCache
            }
        }

        activeDesktopNameCommand = ""
        activeDesktopNamePath = ""
        activeDesktopNameGeneration = -1
        desktopEntryReader.disconnectSource(command)
        Qt.callLater(function() {
            root.startNextDesktopNameRequest()
        })
    }

    function itemDisplayName(fileUrl, fallbackName) {
        var localPath = localPathForUrl(fileUrl)
        if (localPath.length > 0) {
            var cachedName = cachedDesktopEntryName(localPath)
            if (cachedName.length > 0) {
                return cachedName
            }
        }
        return fallbackName
    }

    function physicalNameForUrl(fileUrl, fallbackName) {
        var localPath = localPathForUrl(fileUrl)
        if (localPath.length > 0) {
            var slash = localPath.lastIndexOf("/")
            return slash >= 0 ? localPath.substring(slash + 1) : localPath
        }
        return String(fallbackName || "")
    }

    function scheduleRename() {
        // The native QMenu is a separate transient window. Defer creation/opening
        // until its triggered/aboutToHide sequence has completed, while keeping
        // the Plasmoid popup alive during the hand-off.
        if (renameRequestPending) {
            return
        }
        renameRequestPending = true
        renameDialogOpen = true
        Qt.callLater(function() {
            renameRequestPending = false
            root.beginRename()
        })
    }

    function beginRename() {
        if ((renameDialogObject && renameDialogObject.visible) || renameOpenQueued) {
            return
        }

        var row = renameTargetRow
        if (row < 0 || row >= folderCountModel.count) {
            row = -1
            for (var i = 0; i < folderCountModel.count; ++i) {
                if (folderModel.isSelected(i)) {
                    row = i
                    break
                }
            }
        }
        if (row < 0 || row >= folderCountModel.count) {
            console.warn("[FolderPopup] Rename requested, but no valid selected row was found")
            renameDialogOpen = false
            return
        }

        // The right-click handler stores the corresponding URL as an additional
        // guard and as the source for the initial filename. FolderModel owns the
        // actual rename operation and validates the row before applying it.
        var targetUrl = renameTargetUrl
        if (!targetUrl) {
            console.warn("[FolderPopup] Rename requested without a stored target URL")
            renameDialogOpen = false
            return
        }
        renameInitialName = physicalNameForUrl(targetUrl, "")
        if (renameInitialName.length === 0) {
            console.warn("[FolderPopup] Rename requested, but the selected item's name is empty")
            renameDialogOpen = false
            return
        }

        renameTargetRow = row
        renameTargetUrl = targetUrl
        renameSelectionBoundary = folderModel.fileExtensionBoundary(row)

        renameDialogOpen = true
        console.info("[FolderPopup] Rename request prepared for row", row, "name", renameInitialName)
        openRenameDialogRequested()
    }

    function clearDesktopEntryNameCache() {
        desktopEntryNameCache = []
        desktopNameQueue = []
        desktopNameGeneration += 1
    }

    onBaseFolderUrlChanged: {
        pathStack = []
        renameTargetRow = -1
        renameTargetUrl = null
        clearDesktopEntryNameCache()
        currentFolderUrl = baseFolderUrl
        if (folderModel.url !== baseFolderUrl) {
            folderModel.url = baseFolderUrl
        }
    }

    Component.onCompleted: {
        currentFolderUrl = baseFolderUrl
        if (baseFolderUrl.length > 0) {
            folderModel.url = baseFolderUrl
        }
    }

    Folder.FolderModel {
        id: folderModel
        applet: Plasmoid
        sortMode: {
            // FolderModel sorts by KDirModel's columns: name=0, size=1,
            // modified=2, type=6. These are the same semantics as Dolphin.
            switch (String(plasmoid.configuration.sortField || "name")) {
            case "type": return 6
            case "time": return 2
            case "size": return 1
            default: return 0
            }
        }
        sortDesc: plasmoid.configuration.sortReversed === true
        sortDirsFirst: true
        showHiddenFiles: root.showHidden
        // Parse .desktop files in any selected folder, not only desktop:/.
        // This makes launcher and internet-link Icon= entries available.
        parseDesktopFiles: true
        previews: false
        onUrlChanged: {
            root.currentFolderUrl = url
            root.clearDesktopEntryNameCache()
        }
        // FolderModel's native Rename QAction emits requestRename. Listen to
        // both the model signal and QAction::triggered: the guard in
        // scheduleRename() collapses them into one deferred dialog opening.
        onRequestRename: root.scheduleRename()
        onItemRenamed: root.clearDesktopEntryNameCache()
    }

    Connections {
        target: folderModel.action("rename")
        function onTriggered() {
            root.scheduleRename()
        }
    }

    // Reads only the Name key from local .desktop launchers. The command is
    // fixed; file paths are shell-quoted and never executed as programs.
    Plasma5Support.DataSource {
        id: desktopEntryReader
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            root.finishDesktopEntryNameRequest(sourceName, data)
        }
    }

    FolderDialog {
        id: folderPicker
        title: i18n("Select a folder")
        onAccepted: plasmoid.configuration.folderUrl = selectedFolder.toString()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Choose folder…")
            icon.name: "folder-open"
            onTriggered: folderPicker.open()
        },
        PlasmaCore.Action {
            text: i18n("Refresh contents")
            icon.name: "view-refresh"
            enabled: root.baseFolderUrl.length > 0
            onTriggered: folderModel.refresh()
        },
        PlasmaCore.Action {
            text: i18n("Open the selected folder in the file manager")
            icon.name: "system-file-manager"
            enabled: root.baseFolderUrl.length > 0
            onTriggered: root.openBaseFolder()
        }
    ]

    // The FolderModel itself is passed to the views. This is the same
    // model/delegate arrangement used by Plasma's FolderView and avoids an
    // extra filtered DelegateModel layer that could report rows without
    // displaying delegates. A tiny adapter exposes the live row count.
    DelegateModel {
        id: folderCountModel
        model: folderModel
        delegate: Item { }
    }

    compactRepresentation: Item {
        id: compactView
        implicitWidth: root.compactWidth
        implicitHeight: root.compactHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        // A hover-only visual highlight. HoverHandler observes the pointer
        // without grabbing it, changing the applet geometry, or starting a drag.
        HoverHandler {
            id: compactHover
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Kirigami.Units.mediumSpacing
            color: Kirigami.Theme.highlightColor
            opacity: compactHover.hovered ? 0.13 : 0.0
            border.color: Kirigami.Theme.highlightColor
            border.width: compactHover.hovered ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing / 2

            Item {
                id: folderIconArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0

                // Keep the folder glyph visible as the background. The first
                // four children are drawn as a small icon mosaic inside it.
                Kirigami.Icon {
                    id: mainFolderIcon
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.86
                    height: width
                    source: root.compactIconName
                    fallback: "folder"
                    Accessible.ignored: true
                }

                GridView {
                    id: compactContentsGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * 0.17
                    width: Math.min(parent.width, parent.height) * 0.48
                    height: width
                    cellWidth: width / 2
                    cellHeight: height / 2
                    flow: GridView.FlowLeftToRight
                    model: visible ? folderModel : null
                    interactive: false
                    clip: true
                    cacheBuffer: 0
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.showPreview
                            && folderModel.status === Folder.FolderModel.Ready
                            && folderCountModel.count > 0

                    delegate: Item {
                        required property int index
                        required property var decoration
                        required property var url
                        width: compactContentsGrid.cellWidth
                        height: compactContentsGrid.cellHeight
                        Component.onCompleted: {
                            if (index < 4) {
                                root.requestDesktopEntryName(url, false)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing / 4
                            radius: Kirigami.Units.smallSpacing / 3
                            color: Kirigami.Theme.backgroundColor
                            opacity: 0.96
                            border.width: 1
                            border.color: Kirigami.Theme.disabledTextColor
                            Accessible.ignored: true
                        }

                        Kirigami.Icon {
                            anchors.fill: parent
                            anchors.margins: Math.max(1, Kirigami.Units.smallSpacing / 3)
                            source: decoration
                            fallback: "unknown"
                            Accessible.ignored: true
                        }

                        Accessible.ignored: true
                    }

                    Accessible.ignored: true
                }
            }

            QQC2.Label {
                id: compactTitle
                Layout.fillWidth: true
                Layout.maximumHeight: implicitHeight
                visible: root.compactLabelText.length > 0
                text: root.compactLabelText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
            }
        }

        // Only a tap opens the folder. FolderPopup contains no custom
        // applet-drag handler; desktop placement remains a Plasma-shell feature.
        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: root.expanded = !root.expanded
        }

        Accessible.role: Accessible.Button
        Accessible.name: root.compactLabelText.length > 0
                         ? i18n("%1. Open folder contents", root.compactLabelText)
                         : i18n("Open folder contents")
    }

    fullRepresentation: Item {
        id: popupView
        implicitWidth: root.panelWidth
        implicitHeight: root.panelHeight
        // Keep the popup constrained to the calculated content size.
        // Plasma persists popupWidth/popupHeight after closing a popup. If
        // only preferred/implicit sizes are supplied, those saved dimensions
        // can override future automatic sizing. Matching min/max constraints
        // make the content-driven size authoritative; Plasma's popup host
        // then resizes the window whenever these hints change.
        Layout.minimumWidth: root.panelWidth
        Layout.maximumWidth: root.panelWidth
        Layout.minimumHeight: root.panelHeight
        Layout.maximumHeight: root.panelHeight
        Layout.preferredWidth: root.panelWidth
        Layout.preferredHeight: root.panelHeight

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.RightButton
            onPressed: mouse => {
                folderModel.clearSelection()
                folderModel.openContextMenu(popupView, mouse.modifiers)
                mouse.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: Kirigami.Units.iconSizes.medium
                spacing: Kirigami.Units.smallSpacing

                QQC2.ToolButton {
                    icon.name: "go-previous"
                    enabled: root.pathStack.length > 0
                    display: QQC2.AbstractButton.IconOnly
                    padding: 0
                    Layout.minimumWidth: 0
                    text: i18n("Back")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Back")
                    onClicked: root.goBack()
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.folderTitle(root.currentFolderUrl)
                    elide: Text.ElideMiddle
                    font.bold: true
                }

                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    padding: 0
                    Layout.minimumWidth: 0
                    text: i18n("Refresh contents")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Refresh contents")
                    enabled: root.currentFolderUrl.length > 0
                             && folderModel.status !== Folder.FolderModel.Listing
                    onClicked: folderModel.refresh()
                }

                QQC2.ToolButton {
                    icon.name: "system-file-manager"
                    display: QQC2.AbstractButton.IconOnly
                    padding: 0
                    Layout.minimumWidth: 0
                    text: i18n("Open in file manager")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Open in file manager")
                    enabled: root.currentFolderUrl.length > 0
                    onClicked: root.openCurrentFolder()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: folderModel.status !== Folder.FolderModel.Ready || folderCountModel.count === 0

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Kirigami.Units.largeSpacing * 2)
                    iconName: {
                        if (root.baseFolderUrl.length === 0) {
                            return "folder-open"
                        }
                        if (folderModel.status === Folder.FolderModel.Listing) {
                            return "view-refresh"
                        }
                        if (folderModel.errorString && folderModel.errorString.length > 0) {
                            return "dialog-error"
                        }
                        return "folder"
                    }
                    text: {
                        if (root.baseFolderUrl.length === 0) {
                            return i18n("Select a folder")
                        }
                        if (folderModel.status === Folder.FolderModel.Listing) {
                            return i18n("Loading folder contents…")
                        }
                        if (folderModel.errorString && folderModel.errorString.length > 0) {
                            return i18n("Could not open the folder")
                        }
                        if (folderModel.status === Folder.FolderModel.Ready && folderCountModel.count === 0) {
                            return i18n("Folder is empty")
                        }
                        return i18n("Folder is unavailable")
                    }
                    explanation: {
                        if (root.baseFolderUrl.length === 0) {
                            return i18n("Choose a local folder in Settings or use the button below.")
                        }
                        if (folderModel.status === Folder.FolderModel.Listing) {
                            return i18n("The folder contents are loading.")
                        }
                        if (folderModel.errorString && folderModel.errorString.length > 0) {
                            return folderModel.errorString
                        }
                        if (folderModel.status === Folder.FolderModel.Ready && folderCountModel.count === 0) {
                            return i18n("Add files or open the context menu to create a new item.")
                        }
                        return i18n("Check the folder path and access permissions.")
                    }
                    helpfulAction: root.baseFolderUrl.length === 0 ? chooseFolderAction : null
                }
            }

            GridView {
                id: fileGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: folderModel.status === Folder.FolderModel.Ready && folderCountModel.count > 0
                clip: true
                Layout.minimumHeight: root.gridCellExtent
                cellWidth: root.gridCellExtent
                cellHeight: root.gridCellExtent
                model: folderModel
                cacheBuffer: 0
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                highlight: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.10
                    Accessible.ignored: true
                }
                highlightMoveDuration: Kirigami.Units.shortDuration
                delegate: Item {
                    id: fileDelegate
                    width: fileGrid.cellWidth
                    height: fileGrid.cellHeight
                    required property int index
                    required property var decoration
                    required property bool isDir
                    required property string display
                    required property string displayWrapped
                    required property string type
                    required property var url
                    property string itemLabel: root.itemDisplayName(url, display)
                    visible: index < root.maxItems
                    focus: GridView.isCurrentItem
                    Component.onCompleted: root.requestDesktopEntryName(url, false)

                    Keys.onReturnPressed: event => {
                        root.openItem(fileDelegate.index, fileDelegate.isDir)
                        event.accepted = true
                    }
                    Keys.onEnterPressed: event => {
                        root.openItem(fileDelegate.index, fileDelegate.isDir)
                        event.accepted = true
                    }
                    Keys.onSpacePressed: event => {
                        root.openItem(fileDelegate.index, fileDelegate.isDir)
                        event.accepted = true
                    }

                    Connections {
                        target: folderModel
                        function onDataChanged(topLeft, bottomRight, roles) {
                            if (topLeft && bottomRight
                                && fileDelegate.index >= topLeft.row
                                && fileDelegate.index <= bottomRight.row) {
                                root.requestDesktopEntryName(fileDelegate.url, true)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing / 2
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.highlightColor
                        opacity: itemMouse.containsMouse ? 0.16 : 0
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing / 2

                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(root.iconSize, parent.width - 2)
                            height: width
                            source: fileDelegate.decoration
                            fallback: fileDelegate.isDir ? "folder" : "unknown"
                            Accessible.ignored: true
                        }

                        Text {
                            width: parent.width
                            visible: root.showLabels
                            text: fileDelegate.itemLabel
                            color: Kirigami.Theme.textColor
                            font: Kirigami.Theme.defaultFont
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Accessible.ignored: true
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.text: fileDelegate.itemLabel

                        // Use FolderModel's native KDE/KIO file context menu.
                        // Select the item first so the menu contains actions for
                        // this file (or keeps an existing multi-selection when
                        // the right-clicked item is already part of it).
                        onPressed: mouse => {
                            fileGrid.currentIndex = fileDelegate.index
                            if (mouse.button === Qt.RightButton) {
                                if (!folderModel.isSelected(fileDelegate.index)) {
                                    folderModel.clearSelection()
                                    folderModel.setSelected(fileDelegate.index)
                                }
                                root.renameTargetRow = fileDelegate.index
                                root.renameTargetUrl = fileDelegate.url
                                root.renameInitialName = root.physicalNameForUrl(fileDelegate.url, fileDelegate.display)
                                folderModel.openContextMenu(fileDelegate, mouse.modifiers)
                                mouse.accepted = true
                            }
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                root.openItem(fileDelegate.index, fileDelegate.isDir)
                            }
                        }
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: fileDelegate.itemLabel
                    Accessible.description: fileDelegate.isDir
                                            ? i18n("Open folder")
                                            : i18n("Open file")
                }
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: folderModel.status === Folder.FolderModel.Ready && folderCountModel.count > 0
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: i18n("Showing %1 of %2 items", Math.min(folderCountModel.count, root.maxItems), folderCountModel.count)
            }
        }

        Connections {
            target: root
            function onOpenRenameDialogRequested() {
                // The native QMenu is a transient child of this popup window.
                // Create and open the Dialog only after the QAction signal has
                // unwound and the QMenu has had a chance to close.
                if (!root.renameDialogObject) {
                    root.renameDialogObject = renameDialogComponent.createObject(popupView)
                }
                if (!root.renameDialogObject) {
                    console.warn("[FolderPopup] Could not create the rename dialog")
                    root.renameDialogOpen = false
                    return
                }
                root.renameOpenQueued = true
                console.info("[FolderPopup] Opening rename dialog")
                Qt.callLater(function() {
                    root.renameOpenQueued = false
                    if (root.renameDialogObject && !root.renameDialogObject.visible) {
                        root.renameDialogObject.open()
                    }
                })
            }
        }

        // Created on demand in the expanded popup's own QQuickWindow.
        Component {
            id: renameDialogComponent

            QQC2.Dialog {
                id: renameDialog
                parent: popupView
                x: Math.max(0, Math.round((popupView.width - width) / 2))
                y: Math.max(0, Math.round((popupView.height - height) / 2))
                width: Math.min(popupView.width - 2 * Kirigami.Units.largeSpacing,
                                Kirigami.Units.gridUnit * 24)
                modal: true
                focus: true
                title: i18n("Rename")
                standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
                Component.onDestruction: {
                    if (root.renameDialogObject === renameDialog) {
                        root.renameDialogObject = null
                    }
                    root.renameOpenQueued = false
                }
                onOpened: {
                    root.renameDialogOpen = true
                    renameField.text = root.renameInitialName
                    renameField.forceActiveFocus()
                    renameField.select(0, Math.max(0, root.renameSelectionBoundary))
                }
                onClosed: {
                    root.renameDialogOpen = false
                    root.renameOpenQueued = false
                }
                onAccepted: {
                    // Keep the exact text: leading and trailing spaces are valid
                    // filename characters on Linux. Only an all-whitespace name
                    // is rejected here.
                    var newName = renameField.text
                    if (root.renameTargetRow >= 0 && newName.trim().length > 0) {
                        console.info("[FolderPopup] Renaming row", root.renameTargetRow, "to", newName)
                        folderModel.rename(root.renameTargetRow, newName)
                    }
                    root.renameTargetRow = -1
                    root.renameTargetUrl = null
                }
                onRejected: {
                    root.renameTargetRow = -1
                    root.renameTargetUrl = null
                }
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("New file or folder name:")
                        wrapMode: Text.WordWrap
                    }
                    QQC2.TextField {
                        id: renameField
                        Layout.fillWidth: true
                        text: root.renameInitialName
                        selectByMouse: true
                        onAccepted: renameDialog.accept()
                    }
                }
            }
        }
    }
}
