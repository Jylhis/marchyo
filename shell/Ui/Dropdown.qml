import QtQuick
import qs.Commons

// A choice list that opens inline under its header, so it grows the layout
// instead of needing a popup surface. `options` is a list of strings or of
// { value, label } objects. Enter, Space and Down open it; Up and Down move
// the cursor, Enter picks, Escape closes (and is only consumed while open).
FocusScope {
    id: root

    property var options: []
    property string value: ""
    property string placeholderText: ""
    property bool searchable: false
    property int maxVisibleRows: 6
    property bool open: false
    property int cursor: -1
    property string query: ""

    signal activated(string value)

    readonly property var shown: root.filtered()
    readonly property int rowHeight: Style.panelRowHeight

    implicitWidth: Style.panelWidth
    implicitHeight: header.height + (root.open ? listBox.height + Style.spacing : 0)
    activeFocusOnTab: true

    function valueOf(opt): string {
        return typeof opt === "string" ? opt : String(opt.value);
    }

    function labelOf(opt): string {
        return typeof opt === "string" ? opt : String(opt.label !== undefined ? opt.label : opt.value);
    }

    function filtered(): var {
        const q = root.query.trim().toLowerCase();
        if (!root.searchable || q.length === 0)
            return root.options;
        return root.options.filter(o => root.labelOf(o).toLowerCase().indexOf(q) >= 0);
    }

    readonly property string currentLabel: {
        for (let i = 0; i < root.options.length; i++)
            if (root.valueOf(root.options[i]) === root.value)
                return root.labelOf(root.options[i]);
        return root.placeholderText;
    }

    readonly property bool filterFocused: filter.field.activeFocus

    function openList(): void {
        root.query = "";
        const opts = root.options;
        let idx = 0;
        for (let i = 0; i < opts.length; i++)
            if (root.valueOf(opts[i]) === root.value)
                idx = i;
        root.cursor = idx;
        root.open = true;
        if (root.searchable)
            filter.focusInput();
    }

    function closeList(): void {
        root.open = false;
        if (root.searchable)
            filter.blurInput();
        root.forceActiveFocus();
    }

    function moveCursor(delta: int): void {
        const n = root.shown.length;
        if (n === 0)
            return;
        root.cursor = Math.max(0, Math.min(n - 1, root.cursor + delta));
        list.positionViewAtIndex(root.cursor, ListView.Contain);
    }

    function pick(index: int): void {
        if (index < 0 || index >= root.shown.length)
            return;
        const v = root.valueOf(root.shown[index]);
        root.value = v;
        root.closeList();
        root.activated(v);
    }

    onShownChanged: root.cursor = root.shown.length > 0 ? 0 : -1

    ControlSurface {
        id: header
        width: parent.width
        height: root.rowHeight
        hot: headerMouse.containsMouse
        focused: root.activeFocus && !root.open
        selected: root.open

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.panelPad
            anchors.right: caret.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            color: root.value.length > 0 ? Colors.text : Colors.textFaint
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }

        Text {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: Style.panelPad
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "▴" : "▾"
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.forceActiveFocus();
                root.open ? root.closeList() : root.openList();
            }
        }
    }

    Column {
        id: listBox
        visible: root.open
        y: header.height + Style.spacing
        width: parent.width
        spacing: Style.spacing

        FilterInput {
            id: filter
            visible: root.searchable
            width: parent.width
            text: root.query
            onEdited: root.query = text
            onMoveDown: root.moveCursor(1)
            onMoveUp: root.moveCursor(-1)
            onSubmitted: root.pick(root.cursor)
            onCleared: root.query = ""
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(Math.max(count, 1), root.maxVisibleRows) * root.rowHeight
            clip: true
            model: root.shown
            interactive: count > root.maxVisibleRows

            delegate: ControlSurface {
                required property var modelData
                required property int index

                width: ListView.view.width
                height: root.rowHeight
                flat: true
                hot: rowMouse.containsMouse
                selected: root.valueOf(modelData) === root.value
                focused: index === root.cursor

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.panelPad
                    anchors.right: parent.right
                    anchors.rightMargin: Style.panelPad
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labelOf(modelData)
                    color: Colors.text
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(index)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: I18n.t("ui.noMatches")
                color: Colors.textFaint
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
            }
        }
    }

    Keys.onPressed: e => {
        if (!root.open) {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space || e.key === Qt.Key_Down) {
                root.openList();
                e.accepted = true;
            }
            return;
        }
        if (e.key === Qt.Key_Down) {
            root.moveCursor(1);
        } else if (e.key === Qt.Key_Up) {
            root.moveCursor(-1);
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.pick(root.cursor);
        } else if (e.key === Qt.Key_Escape) {
            root.closeList();
        } else {
            return;
        }
        e.accepted = true;
    }
}
