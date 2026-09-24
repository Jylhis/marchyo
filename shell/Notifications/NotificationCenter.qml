import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import qs.Services

// The notification centre: a summonable history panel (panelId "notifications")
// over the retained NotificationState.history. Reuses Ui/Panel's chrome and the
// shared PanelManager, so it registers the same way every other panel does (one
// shared string, no manifest). Opening it marks the history read. Each row can
// be dismissed individually; a header button clears the lot. History holds data
// snapshots, so this renders plain fields, not live Notification objects.
Panel {
    id: root

    panelId: "notifications"
    title: "Notifications"

    // Opening the centre clears the unread badge.
    onVisibleChanged: {
        if (visible)
            NotificationState.markAllRead();
    }

    body: [
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            Text {
                Layout.fillWidth: true
                text: NotificationState.history.length > 0 ? (NotificationState.history.length + " total") : ""
                color: Color.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
            }

            PanelButton {
                text: "Clear all"
                visible: NotificationState.history.length > 0
                onClicked: NotificationState.clearHistory()
            }
        },
        Text {
            Layout.fillWidth: true
            visible: NotificationState.history.length === 0
            text: "No notifications"
            color: Color.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        ListView {
            id: list
            visible: NotificationState.history.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.notifCenterMaxHeight)
            model: NotificationState.history
            clip: true
            spacing: Style.panelGap
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: list.width
                implicitHeight: entryLayout.implicitHeight + Style.panelPad
                radius: Style.notifRadius
                color: modelData.unread ? Color.surfaceRaised : Color.surface
                border.width: 1
                border.color: Color.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // Either button dismisses the row from history.
                    onClicked: NotificationState.removeHistory(modelData.id)
                }

                ColumnLayout {
                    id: entryLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(Style.panelPad / 2)
                    spacing: Math.round(Style.spacing / 2)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacing

                        Text {
                            Layout.fillWidth: true
                            text: modelData.appName.length > 0 ? modelData.appName : "notification"
                            color: Color.textMuted
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                            elide: Text.ElideRight
                        }
                        Text {
                            text: Qt.formatDateTime(new Date(modelData.timeMs), "hh:mm")
                            color: Color.textFaint
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.summary
                        color: Color.textHeading
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: modelData.body.length > 0
                        text: modelData.body
                        color: Color.text
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }
        }
    ]
}
