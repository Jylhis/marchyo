import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

// Renders one provider's `results` (see Launcher/Provider.qml): a row list,
// or a glyph grid for `layout: "grid"` providers (emoji); list rows can carry
// a thumbnail (Provider.previews, the clipboard). Owns the selection;
// LauncherWindow routes the arrow keys and Enter here.
Item {
    id: root

    required property var provider

    readonly property bool grid: root.provider.layout === "grid"
    readonly property var results: root.provider.results || []
    readonly property int rowHeight: Style.panelRowHeight
    readonly property int maxRows: root.provider.maxRows
    // Rows with a thumbnail (provider.previews) are three rows tall; the
    // thumbnail box is landscape so screenshots and snippets both fit.
    readonly property int previewRowHeight: root.rowHeight * 3
    readonly property int previewHeight: root.previewRowHeight - Style.spacing * 2
    readonly property int previewWidth: root.previewHeight * 2
    readonly property int cellSize: Style.panelRowHeight + Style.panelPad
    readonly property int gridRows: Math.max(1, Math.ceil(root.results.length / root.provider.columns))
    readonly property var view: root.grid ? gridView : listView

    // ListView/GridView implicitHeight is 0 even with delegates (verified
    // offscreen), so size from contentHeight (list, capped at maxRows) or the
    // row count (grid, capped at six rows).
    implicitHeight: root.grid ? gridView.height : (listView.count > 0 ? Math.min(listView.contentHeight, root.rowHeight * root.maxRows + Style.spacing * (root.maxRows - 1)) : root.rowHeight)

    // The first row is selected once the user has typed (or immediately for
    // selectOnEmpty providers); each new result set resets the selection.
    function defaultIndex() {
        if (root.results.length === 0)
            return -1;
        return root.provider.selectOnEmpty || root.provider.query.trim().length > 0 ? 0 : -1;
    }

    // Selects row `index`, clamped to the list; -1 when the list is empty.
    function select(index) {
        const v = root.view;
        if (v.count === 0)
            return -1;
        v.currentIndex = Math.max(0, Math.min(v.count - 1, index));
        return v.currentIndex;
    }

    function move(delta) {
        root.select(root.view.currentIndex + delta);
    }

    function activate() {
        const r = root.results[root.view.currentIndex];
        if (r)
            r.activate();
    }

    function titleMarkup(r) {
        const title = Fuzzy.highlight(r.title, r.positions, Colors.accent.toString());
        if (!r.subtitle)
            return title;
        return title + ' <font color="' + Colors.textMuted.toString() + '">· ' + Fuzzy.escapeHtml(r.subtitle) + "</font>";
    }

    ListView {
        id: listView
        anchors.fill: parent
        visible: !root.grid
        spacing: Style.spacing
        clip: true
        model: root.grid ? [] : root.results
        onModelChanged: currentIndex = root.defaultIndex()

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            // "" unless this provider draws thumbnails and the row has one.
            readonly property string previewKey: root.provider.previews ? (row.modelData.preview || "") : ""
            width: ListView.view.width
            height: row.previewKey !== "" ? root.previewRowHeight : root.rowHeight
            color: ListView.isCurrentItem ? Colors.surfaceRaised : "transparent"
            border.width: ListView.isCurrentItem ? 1 : 0
            border.color: Colors.accent

            // Delegates exist only for rows in (or near) view, so this is
            // what keeps thumbnail decoding to the visible rows.
            Component.onCompleted: if (row.previewKey !== "")
                root.provider.requestPreview(row.modelData)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    listView.currentIndex = row.index;
                    root.activate();
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.margins: Style.paddingH
                spacing: Style.spacing

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.provider.showIcons
                    source: root.provider.showIcons ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                    implicitSize: Style.fontSize + 8
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.previewKey !== ""
                    width: root.previewWidth
                    height: root.previewHeight
                    color: Colors.bgSubtle
                    border.width: 1
                    border.color: Colors.border

                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 1
                        source: row.previewKey !== "" ? (root.provider.previewSources[row.previewKey] || "") : ""
                        // Decode at thumbnail size, never the full image.
                        sourceSize.width: root.previewWidth
                        sourceSize.height: root.previewHeight
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        // Pending decode vs failed decode / unloadable file.
                        text: row.previewKey !== "" && root.provider.previewSources[row.previewKey] === undefined ? "\u2026" : I18n.t("launcher.image")
                        color: Colors.textFaint
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: root.provider.highlight ? Text.StyledText : Text.PlainText
                    text: root.provider.highlight ? root.titleMarkup(row.modelData) : row.modelData.title
                    color: row.ListView.isCurrentItem ? Colors.textHeading : Colors.text
                    font.family: Style.fontFamily
                    font.pixelSize: root.provider.compact ? Style.fontSizeSmall : Style.fontSize
                    elide: Text.ElideRight
                    width: row.width - Style.paddingH * (root.provider.showIcons ? 4 : 2) - (row.previewKey !== "" ? root.previewWidth + Style.spacing : 0) - trailing.width
                }
            }

            // A short marker at the row's right edge: a check, a submenu
            // chevron or a chord (rows set `trailing`).
            Text {
                id: trailing
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.paddingH
                text: row.modelData.trailing || ""
                color: row.modelData.checked ? Colors.accent : Colors.textMuted
                font.family: Style.fontFamily
                font.pixelSize: root.provider.compact ? Style.fontSizeSmall : Style.fontSize
            }
        }
    }

    GridView {
        id: gridView
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.grid
        height: root.grid ? Math.min(root.cellSize * 6, root.gridRows * root.cellSize) : 0
        clip: true
        model: root.grid ? root.results : []
        onModelChanged: currentIndex = root.defaultIndex()
        cellWidth: Math.floor(width / root.provider.columns)
        cellHeight: root.cellSize

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: gridView.cellWidth
            height: gridView.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: cell.GridView.isCurrentItem ? Colors.surfaceRaised : "transparent"
                border.width: cell.GridView.isCurrentItem ? 1 : 0
                border.color: Colors.accent
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.title
                // Deliberately not Style.fontFamily: no Nerd mono face
                // carries emoji glyphs; fontconfig falls back to the emoji
                // font (noto-fonts-color-emoji, installed by fonts.nix).
                font.pixelSize: Style.fontSize + 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    gridView.currentIndex = cell.index;
                    root.activate();
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.view.count === 0
        text: root.provider.emptyText
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }
}
