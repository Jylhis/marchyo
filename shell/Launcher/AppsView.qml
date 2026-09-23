import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import "../Commons/Match.js" as Match

// App search over Quickshell's DesktopEntries model (the same source of
// truth the app grid uses; marchyo's xdg.desktopEntries webapps flow in
// automatically). Pure view: the entry list is seat-global, scoring is the
// Node-tested Match.js, launching is DesktopEntry.execute().
Item {
    id: root

    property string query: ""
    readonly property int maxResults: 8
    readonly property int rowHeight: Style.panelRowHeight

    readonly property var entries: DesktopEntries.applications.values

    // Recomputed on query or entry-set change. noDisplay entries (hidden
    // by their own file) never show; empty query lists names A→Z.
    readonly property var matches: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            if (e.noDisplay)
                continue;
            const s = Match.score(e.name, q);
            if (s < 0)
                continue;
            out.push({
                entry: e,
                score: s
            });
        }
        out.sort((a, b) => (b.score - a.score) || a.entry.name.localeCompare(b.entry.name));
        return out.slice(0, root.maxResults);
    }

    implicitHeight: list.count > 0 ? list.implicitHeight : rowHeight

    ListView {
        id: list
        anchors.fill: parent
        spacing: Style.spacing
        clip: true
        model: root.matches
        currentIndex: root.query.trim().length > 0 ? 0 : -1

        delegate: Rectangle {
            id: delegate
            required property var modelData
            required property int index
            width: ListView.view.width
            height: root.rowHeight
            color: ListView.isCurrentItem ? Color.surfaceRaised : "transparent"
            border.width: ListView.isCurrentItem ? 1 : 0
            border.color: Color.accent

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.currentIndex = delegate.index;
                    root.activate();
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.margins: Style.paddingH
                spacing: Style.spacing

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Quickshell.iconPath(modelData.entry.icon)
                    sourceSize.width: Style.fontSize + 8
                    sourceSize.height: Style.fontSize + 8
                    visible: source.toString().length > 0
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.entry.name
                    color: delegate.ListView.isCurrentItem ? Color.textHeading : Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    elide: Text.ElideRight
                    width: parent.parent.width - Style.paddingH * 4
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: "no matches"
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    function move(delta) {
        if (list.count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
    }

    function activate() {
        const m = root.matches[list.currentIndex];
        if (!m)
            return;
        Launcher.close();
        m.entry.execute();
    }
}
