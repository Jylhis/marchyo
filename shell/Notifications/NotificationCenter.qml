import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/notify/Markup.js" as Markup

// Summonable history panel over the retained NotificationState.history. Opening
// it marks the history read. History holds data snapshots, so this renders plain
// fields, not live Notification objects.
//
// Keyboard (the Phase 0 panel contract): Tab or Down from the header reaches the
// list, Up and Down walk the rows, Enter opens the row's link or the sender's
// window, Delete or Backspace removes it, Escape closes the panel.
Panel {
    id: root

    panelId: "notifications"
    title: I18n.t("notifications.title")

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
                text: NotificationState.history.length > 0 ? I18n.t("notifications.total", NotificationState.history.length) : ""
                color: Colors.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
            }

            PanelButton {
                text: I18n.t("notifications.clearAll")
                visible: NotificationState.history.length > 0
                onClicked: NotificationState.clearHistory()
            }
        },
        Text {
            Layout.fillWidth: true
            visible: NotificationState.history.length === 0
            text: I18n.t("notifications.empty")
            color: Colors.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: NotificationState.history.length > 0
            text: I18n.t("notifications.keyHint")
            color: Colors.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        ListView {
            id: list
            visible: NotificationState.history.length > 0
            activeFocusOnTab: true
            keyNavigationEnabled: true
            keyNavigationWraps: false
            currentIndex: 0
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.notifCenterMaxHeight)
            model: NotificationState.history
            clip: true
            spacing: Style.panelGap
            boundsBehavior: Flickable.StopAtBounds

            function current() {
                return list.currentIndex >= 0 && list.currentIndex < NotificationState.history.length ? NotificationState.history[list.currentIndex] : null;
            }

            Keys.onPressed: e => {
                const entry = list.current();
                if (entry === null)
                    return;
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    NotificationState.activateHistory(entry);
                } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
                    NotificationState.removeHistory(entry.id);
                } else {
                    return;
                }
                e.accepted = true;
            }

            delegate: ControlSurface {
                id: row
                required property var modelData
                required property int index
                width: list.width
                implicitHeight: entryLayout.implicitHeight + Style.panelPad
                radius: Style.notifRadius
                hot: rowMouse.containsMouse
                focused: list.activeFocus && ListView.isCurrentItem
                selected: modelData.unread

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        list.currentIndex = row.index;
                        if (mouse.button === Qt.LeftButton)
                            NotificationState.activateHistory(row.modelData);
                        else
                            NotificationState.removeHistory(row.modelData.id);
                    }
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
                            text: modelData.appName.length > 0 ? modelData.appName : I18n.t("notifications.app")
                            textFormat: Text.PlainText
                            color: Colors.textMuted
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                            elide: Text.ElideRight
                        }
                        Text {
                            text: Qt.formatDateTime(new Date(modelData.timeMs), "hh:mm")
                            color: Colors.textFaint
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.summary
                        textFormat: Text.PlainText
                        color: Colors.textHeading
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
                        text: Markup.render(modelData.body)
                        color: Colors.text
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
