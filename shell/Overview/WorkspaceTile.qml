import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Services
import "../Commons/Overview.js" as Ov

// One workspace in the overview grid: a scaled-down picture of its monitor
// with a WindowPreview per window at its real position. A click on empty
// tile area switches to the workspace. Dimmed while a search matches none
// of its windows.
Rectangle {
    id: root

    // A Commons/Overview.js groupByWorkspace entry.
    required property var workspace

    readonly property var monitor: Overview.monitors[root.workspace.monitorId] || null
    readonly property bool current: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === root.workspace.id
    readonly property bool anyMatch: {
        const ws = root.workspace.windows;
        for (let i = 0; i < ws.length; i++)
            if (Overview.matches[ws[i].address] !== undefined)
                return true;
        return false;
    }

    radius: Style.panelRadius
    color: Qt.alpha(Color.bg, Style.surfaceAlpha)
    border.width: Style.borderWidth
    border.color: root.current ? Color.accent : Color.border
    opacity: Overview.query.trim().length > 0 && !root.anyMatch ? 0.4 : 1
    clip: true

    MouseArea {
        anchors.fill: parent
        onClicked: Overview.goToWorkspace(root.workspace.id)
    }

    Repeater {
        model: root.workspace.windows

        WindowPreview {
            required property var modelData
            window: modelData
            rect: Ov.windowRect(modelData, root.monitor || Overview.monitors[modelData.monitorId] || null, root.width, root.height)
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.spacing * 2
        text: root.workspace.name
        color: root.current ? Color.accent : Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        font.bold: true
    }
}
