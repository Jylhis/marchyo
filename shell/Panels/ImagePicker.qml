import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Appearance.js" as Appearance
import "../Commons/LauncherProviders.js" as Providers

// Keyboard-first image grid behind the "themes" and "backgrounds" panels
// (`kind`): a filter field, the tiles, and a large preview of the focused one.
// Arrows move the selection, Enter applies it, Escape closes (the filter
// field clears first). Rows come from Services/Pickers; wallpapers draw their
// cached thumbnail (Services/Thumbnails) and fall back to the full image. A
// theme without a preview.png gets a plain tile with its name.
Panel {
    id: root

    property string kind: "themes"

    panelId: root.kind
    title: I18n.t("picker." + root.kind + ".title")
    centered: true
    cardWidth: Math.min(Math.round(Style.launcherWidth * 1.5), Math.max(Style.launcherWidth, root.screen ? root.screen.width - 4 * Style.panelPad : 0))

    property int index: 0
    property bool touched: false

    readonly property var shown: Providers.rank(Pickers.rows(root.kind), filter.text, (text, q) => Fuzzy.match(text, q))
    readonly property var focusRow: root.index >= 0 && root.index < root.shown.length ? root.shown[root.index] : null
    readonly property bool loading: Pickers.loading(root.kind)

    function preselect(): void {
        if (!root.touched)
            root.index = Appearance.currentIndex(root.shown);
    }

    onShownChanged: Qt.callLater(root.preselect)

    onIndexChanged: grid.positionViewAtIndex(root.index, GridView.Contain)

    function move(key: string): void {
        root.touched = true;
        gate.hold();
        root.index = Appearance.step(root.index, key, grid.columns, root.shown.length);
    }

    function applyFocused(): void {
        if (root.focusRow)
            Pickers.apply(root.kind, root.focusRow.id);
    }

    function tileSource(row): string {
        if (!row || row.image === "")
            return "";
        return root.kind === "backgrounds" ? Thumbnails.sourceFor(row.image) : "file://" + row.image;
    }

    readonly property var opened: Connections {
        target: root
        function onVisibleChanged() {
            if (!root.visible)
                return;
            root.touched = false;
            filter.clear();
            root.index = Appearance.currentIndex(root.shown);
            Qt.callLater(filter.focusInput);
        }
    }

    readonly property var filterKeys: Connections {
        target: filter
        function onKeyPressed(e) {
            const keys = {};
            keys[Qt.Key_Left] = "left";
            keys[Qt.Key_Right] = "right";
            keys[Qt.Key_Home] = "home";
            keys[Qt.Key_End] = "end";
            keys[Qt.Key_PageUp] = "up";
            keys[Qt.Key_PageDown] = "down";
            if (keys[e.key] === undefined)
                return;
            root.move(keys[e.key]);
            e.accepted = true;
        }
    }

    body: [
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.panelPad

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                Layout.alignment: Qt.AlignTop
                spacing: Style.spacing

                FilterInput {
                    id: filter
                    Layout.fillWidth: true
                    onMoveDown: root.move("down")
                    onMoveUp: root.move("up")
                    onSubmitted: root.applyFocused()
                    onEdited: {
                        root.touched = true;
                        root.index = 0;
                    }
                    onCleared: {
                        root.touched = true;
                        root.index = 0;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: grid.cellHeight * 3

                    PointerMoveGate {
                        id: gate
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.index
                        model: root.shown

                        readonly property int columns: Math.max(1, Math.floor(grid.width / (Style.fontSize * 11)))
                        cellWidth: Math.floor(grid.width / grid.columns)
                        cellHeight: Math.round(grid.cellWidth * 9 / 16) + Style.fontSizeSmall + Style.panelPad

                        delegate: Item {
                            id: tile
                            required property var modelData
                            required property int index

                            width: grid.cellWidth
                            height: grid.cellHeight

                            ControlSurface {
                                anchors.fill: parent
                                anchors.margins: Math.round(Style.spacing / 2)
                                selected: tile.index === root.index
                                hot: tileMouse.containsMouse

                                Item {
                                    id: art
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Style.borderFocus
                                    height: Math.round(width * 9 / 16)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Style.panelRadius
                                        color: Colors.bgSubtle
                                    }

                                    PickerImage {
                                        anchors.fill: parent
                                        source: root.tileSource(tile.modelData)
                                        held: {
                                            const top = grid.contentY;
                                            const bottom = top + grid.height;
                                            return root.visible && tile.y + tile.height >= top && tile.y <= bottom;
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: Style.spacing
                                        visible: tile.modelData.image === ""
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        text: tile.modelData.title
                                        color: Colors.textMuted
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.fontSizeSmall
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: Style.spacing
                                        visible: tile.modelData.current
                                        width: Style.fontSizeSmall
                                        height: width
                                        radius: width / 2
                                        color: Colors.accent
                                        border.color: Colors.bg
                                        border.width: Style.borderWidth
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: art.bottom
                                    anchors.margins: Style.spacing
                                    text: tile.modelData.title
                                    elide: Text.ElideRight
                                    color: Colors.text
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.fontSizeSmall
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: {
                                        if (Pointer.moved) {
                                            root.touched = true;
                                            root.index = tile.index;
                                        }
                                    }
                                    onClicked: {
                                        root.touched = true;
                                        root.index = tile.index;
                                        root.applyFocused();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.shown.length === 0
                        text: root.loading ? I18n.t("picker.loading") : I18n.t("picker.empty")
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.alignment: Qt.AlignTop
                spacing: Style.spacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(width * 9 / 16)
                    radius: Style.panelRadius
                    color: Colors.bgSubtle
                    border.color: Colors.border
                    border.width: Style.borderWidth

                    PickerImage {
                        anchors.fill: parent
                        anchors.margins: Style.borderWidth
                        source: root.focusRow && root.focusRow.image !== "" ? "file://" + root.focusRow.image : ""
                        held: root.visible
                        holdMs: 60000
                        decodeSize: Qt.size(960, 540)
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: Style.panelPad
                        visible: root.focusRow !== null && root.focusRow.image === ""
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        text: root.focusRow ? root.focusRow.title : ""
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.focusRow ? root.focusRow.title : ""
                    elide: Text.ElideRight
                    color: Colors.textHeading
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.focusRow ? (root.focusRow.current ? I18n.t("picker.current", root.focusRow.subtitle) : root.focusRow.subtitle) : ""
                    elide: Text.ElideRight
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
            }
        },
        Text {
            Layout.fillWidth: true
            text: I18n.t("picker.hint")
            color: Colors.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    ]
}
