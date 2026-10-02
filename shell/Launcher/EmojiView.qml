import QtQuick
import qs.Commons
import qs.Services
import "../Commons/EmojiData.js" as EmojiData
import "../Commons/Match.js" as Match

// Emoji picker: a grid over Commons/EmojiData.js (full catalog in the store
// shell, a dev subset from the tree), searched by name with Match.js.
// Activating copies AND types the emoji at the cursor (vicinae parity); see
// Services/Launcher.pasteText.
Item {
    id: root

    property string query: ""
    property int cellSize: Style.panelRowHeight + Style.panelPad
    property int columns: 8

    readonly property var allEmoji: EmojiData.parse(EmojiData.RAW)
    readonly property var matches: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.allEmoji.length; i++) {
            const e = root.allEmoji[i];
            if (q.length === 0 || Match.score(e.name, q) >= 0)
                out.push(e);
        }
        return out;
    }

    // GridView.implicitHeight is 0 even with cells (same offscreen result as
    // the apps ListView), so compute rows from the match count; the grid height
    // follows and the Item mirrors it.
    readonly property int rows: Math.max(1, Math.ceil(root.matches.length / root.columns))
    implicitHeight: grid.height

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(root.cellSize * 6, root.rows * root.cellSize)
        clip: true
        model: root.matches
        cellWidth: Math.floor(width / root.columns)
        cellHeight: root.cellSize
        currentIndex: root.query.trim().length > 0 && count > 0 ? 0 : -1

        delegate: Item {
            id: delegate
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: delegate.GridView.isCurrentItem ? Color.surfaceRaised : "transparent"
                border.width: delegate.GridView.isCurrentItem ? 1 : 0
                border.color: Color.accent
            }

            Text {
                anchors.centerIn: parent
                text: delegate.modelData.chars
                // Deliberately not Style.fontFamily: no Nerd mono face
                // carries emoji glyphs; fontconfig falls back to the emoji
                // font (noto-fonts-color-emoji, installed by fonts.nix).
                font.pixelSize: Style.fontSize + 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    grid.currentIndex = delegate.index;
                    root.activate();
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: grid.count === 0
        text: "no emoji"
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    function move(delta) {
        if (grid.count === 0)
            return;
        grid.currentIndex = Math.max(0, Math.min(grid.count - 1, grid.currentIndex + delta));
    }

    function activate() {
        const e = root.matches[grid.currentIndex];
        if (!e)
            return;
        Launcher.close();
        Launcher.pasteText(e.chars);
    }
}
