import QtQuick
import qs.Services
import qs.Commons

// One sender's toasts. Collapsed it shows the newest card with the edges of the
// cards behind it; hovering the deck (or selecting one of its cards with the
// keyboard) expands it into the full list.
Item {
    id: root

    // { key, rows: [{ n, count, ... }] } from NotificationState.decks.
    required property var deck
    property var selectedNotif: null

    readonly property bool expanded: hover.hovered || root.deck.rows.some(r => r.n === root.selectedNotif)
    readonly property int peekCount: Math.min(root.deck.rows.length - 1, 2)
    readonly property int peek: 8

    implicitHeight: column.implicitHeight + (root.expanded ? 0 : root.peekCount * root.peek)

    HoverHandler {
        id: hover
    }

    Repeater {
        model: root.expanded ? 0 : root.peekCount

        Rectangle {
            required property int index
            x: (index + 1) * root.peek
            y: column.implicitHeight - 4 + index * root.peek
            width: root.width - x * 2
            height: root.peek + 4
            z: -1 - index
            radius: Style.notifRadius
            color: Qt.alpha(Colors.bg, Style.surfaceAlpha)
            border.width: Style.notifBorder
            border.color: Colors.border
        }
    }

    Column {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.notifGap

        Repeater {
            model: root.deck.rows

            NotificationPopup {
                required property var modelData
                required property int index
                visible: root.expanded || index === 0
                selected: root.selectedNotif === modelData.n
                expanded: root.expanded
                count: modelData.count
                width: parent.width
                notif: modelData.n
            }
        }
    }
}
