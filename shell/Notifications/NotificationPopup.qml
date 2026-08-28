import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Ui
import qs.Services
import qs.Commons

// One themed toast card: presentational plus its own lifecycle. Reads a live
// Notification, auto-expires on the sender's timeout (or a per-urgency default),
// dismisses on click, and removes itself from the shared stack when the
// notification is closed anywhere. Sharp corners + a 2px urgency-coloured border
// keep mako's TUI aesthetic.
Rectangle {
    id: root

    required property var notif

    radius: Style.notifRadius
    color: Color.bg
    border.width: Style.notifBorder
    border.color: {
        if (!notif)
            return Color.border;
        if (notif.urgency === NotificationUrgency.Critical)
            return Color.statusErr;
        if (notif.urgency === NotificationUrgency.Low)
            return Color.textFaint;
        return Color.border;
    }

    implicitHeight: layout.implicitHeight + Style.notifPad * 2

    // Auto-expire: honour the sender's timeout when positive (expireTimeout is in
    // seconds), else the per-urgency default. 0 = never (critical persist).
    readonly property int timeoutMs: {
        if (!notif)
            return Style.notifTimeoutNormal;
        if (notif.expireTimeout > 0)
            return Math.round(notif.expireTimeout * 1000);
        if (notif.urgency === NotificationUrgency.Critical)
            return Style.notifTimeoutCritical;
        if (notif.urgency === NotificationUrgency.Low)
            return Style.notifTimeoutLow;
        return Style.notifTimeoutNormal;
    }

    Timer {
        running: root.timeoutMs > 0
        interval: Math.max(1, root.timeoutMs)
        onTriggered: {
            if (root.notif)
                root.notif.expire();
            NotificationState.remove(root.notif);
        }
    }

    // Drop the card if the notification is closed elsewhere (app-closed, replaced,
    // or dismissed via clearAll).
    Connections {
        target: root.notif
        function onClosed(reason) {
            NotificationState.remove(root.notif);
        }
    }

    // Dismiss area, declared first so the content (and its action buttons) render
    // above it and take their own clicks; a click on empty card area falls through
    // to here. Left-click fires the notification's "default" action if it has one.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton && root.notif) {
                for (let i = 0; i < root.notif.actions.length; i++) {
                    if (root.notif.actions[i].identifier === "default") {
                        root.notif.actions[i].invoke();
                        break;
                    }
                }
            }
            if (root.notif)
                root.notif.dismiss();
            NotificationState.remove(root.notif);
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.notifPad
        spacing: Style.spacing

        Image {
            id: icon
            Layout.preferredWidth: Style.notifIconSize
            Layout.preferredHeight: Style.notifIconSize
            Layout.alignment: Qt.AlignTop
            visible: source.toString().length > 0
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            source: {
                if (!root.notif)
                    return "";
                if (root.notif.image && root.notif.image.length > 0)
                    return root.notif.image;
                const ai = root.notif.appIcon;
                if (ai && ai.length > 0) {
                    if (ai.indexOf("/") === 0)
                        return "file://" + ai;
                    if (ai.indexOf("file://") === 0 || ai.indexOf("image://") === 0)
                        return ai;
                    // Resolve a themed icon name; the second arg checks existence so a
                    // missing icon yields "" rather than Qt's broken-texture placeholder.
                    return Quickshell.iconPath(ai, true);
                }
                return "";
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(Style.spacing / 2)

            Text {
                Layout.fillWidth: true
                text: root.notif ? root.notif.summary : ""
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
                visible: root.notif && root.notif.body.length > 0
                text: root.notif ? root.notif.body : ""
                color: Color.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                // bodyMarkupSupported: senders send a limited HTML subset (<b>/<i>/<a>).
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            // Action buttons. Skip the implicit "default" action (invoked on body
            // click instead) so the row stays clean.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(Style.spacing / 2)
                spacing: Style.spacing
                visible: root.notif && root.notif.actions.length > 0

                Repeater {
                    model: root.notif ? root.notif.actions : []

                    PanelButton {
                        required property var modelData
                        visible: modelData.identifier !== "default"
                        text: modelData.text
                        onClicked: {
                            modelData.invoke();
                            if (root.notif && !root.notif.resident)
                                NotificationState.remove(root.notif);
                        }
                    }
                }
            }
        }
    }
}
