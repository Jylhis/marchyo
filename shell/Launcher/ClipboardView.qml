import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/Cliphist.js" as Cliphist
import "../Commons/Match.js" as Match

// Clipboard history over `cliphist list` (fed by the wl-paste watchers in
// modules/home/hyprland.nix). The listing subprocess runs once per open —
// a refresh, not a poll — and rows decode in JS (Commons/Cliphist.js).
// Text entries only; binary/image rows are skipped by Cliphist.parseLine.
Item {
    id: root

    property string query: ""
    readonly property int maxRows: 12
    readonly property int maxHistory: 500

    property var items: []

    readonly property var matches: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.items.length && out.length < root.maxRows; i++) {
            const it = root.items[i];
            if (q.length === 0 || Match.score(it.text, q) >= 0)
                out.push(it);
        }
        return out;
    }

    implicitHeight: list.contentHeight > 0 ? Math.min(list.contentHeight, Style.panelRowHeight * maxRows + Style.spacing * (maxRows - 1)) : Style.panelRowHeight

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        spacing: Style.spacing
        clip: true
        model: root.matches
        currentIndex: count > 0 ? 0 : -1

        delegate: Rectangle {
            id: delegate
            required property var modelData
            required property int index
            width: ListView.view.width
            height: Style.panelRowHeight
            color: delegate.ListView.isCurrentItem ? Color.surfaceRaised : "transparent"
            border.width: delegate.ListView.isCurrentItem ? 1 : 0
            border.color: Color.accent

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.currentIndex = delegate.index;
                    root.activate();
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.margins: Style.paddingH
                width: parent.width - Style.paddingH * 2
                text: delegate.modelData.text
                color: delegate.ListView.isCurrentItem ? Color.textHeading : Color.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: "clipboard history is empty"
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    // One listing per open: rerunning the process both refreshes the rows
    // and replaces the model, so no stale merge logic is needed.
    readonly property var listProc: Process {
        id: listProc
        command: [Config.cliphist, "list"]
        stdout: SplitParser {
            onRead: line => {
                const parsed = Cliphist.parseLine(line);
                if (parsed && root.items.length < root.maxHistory)
                    root.items = root.items.concat(parsed);
            }
        }
    }

    Connections {
        target: Launcher
        function onModeChanged() {
            if (Launcher.mode === "clipboard") {
                root.items = [];
                root.refresh();
            }
        }
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function move(delta) {
        if (list.count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
    }

    function activate() {
        const it = root.matches[list.currentIndex];
        if (!it)
            return;
        Launcher.close();
        Launcher.pasteText(it.text);
    }
}
