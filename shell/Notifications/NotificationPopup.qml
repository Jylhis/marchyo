import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Ui
import qs.Services
import qs.Commons
import "../Commons/notify/Security.js" as Security
import "../Commons/NotificationIcons.js" as Icons
import "../Commons/NotificationCard.js" as NotificationCard

// One themed toast card. Reads a live Notification, dismisses on click, and removes
// itself from the shared stack when the notification is closed anywhere. Width comes
// from the parent, not Layout.fillWidth, because the stack is a Column positioner.
Rectangle {
    id: root

    required property var notif
    // Chosen by the keyboard bind: accent border and numbered buttons.
    property bool selected: false
    property bool expanded: false
    property string copiedCode: ""
    readonly property double now: Clock.date.getTime()
    readonly property bool hovered: hover.hovered && root.visible
    LayoutMirroring.enabled: I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    onHoveredChanged: NotificationState.pauseExpiry(root.notif, root.hovered)
    Component.onDestruction: NotificationState.pauseExpiry(root.notif, false)

    HoverHandler {
        id: hover
    }

    Timer {
        id: copiedTimer
        interval: 1600
        onTriggered: root.copiedCode = ""
    }

    function ageLabel() {
        if (!root.row)
            return "";
        const ts = root.row.ts * 1000;
        const age = NotificationCard.age(ts, root.now);
        if (age.kind === "minutes")
            return I18n.t("notifications.ageMinutes", I18n.formatNumber(age.value, 0));
        if (age.kind === "yesterday")
            return I18n.t("notifications.ageYesterday");
        return Qt.formatDateTime(new Date(ts), age.kind === "time" ? "HH:mm" : "dd MMM");
    }
    // Identical repeats collapsed into this card.
    property int count: 1
    readonly property var codes: root.notif ? NotificationState.codesOf(root.notif) : []
    // `marchyo notify --glyph` replaces the icon; --action/--exec buttons come
    // from NotificationState.deedsOf (vetted argv arrays, never a shell string).
    readonly property var row: root.notif ? NotificationState.rowOf(root.notif) : null
    readonly property string glyph: root.row ? root.row.glyph : ""
    readonly property var deeds: root.notif ? NotificationState.deedsOf(root.notif) : []

    radius: Style.notifRadius
    color: Qt.alpha(Colors.bg, Style.surfaceAlpha)
    border.width: Style.notifBorder
    border.color: {
        if (root.selected)
            return Colors.accent;
        if (!notif)
            return Colors.border;
        if (notif.urgency === NotificationUrgency.Critical)
            return Colors.statusErr;
        if (notif.urgency === NotificationUrgency.Low)
            return Colors.textFaint;
        return Colors.border;
    }

    implicitHeight: layout.implicitHeight + Style.notifPad * 2

    // No expiry Timer here on purpose: this delegate is destroyed and rebuilt
    // whenever any notification is added or removed (the stack is a value model),
    // so a per-delegate countdown would restart on every arrival and older toasts
    // would never expire. NotificationState owns the deadlines and sweeps them.

    Connections {
        target: root.notif
        function onClosed(reason) {
            NotificationState.remove(root.notif);
        }
    }

    // Declared before the content so the action buttons stack above it and take their
    // own clicks; clicks on empty card area fall through here (left-click also fires
    // the default action, if any).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (!root.notif)
                return;
            if (mouse.button === Qt.LeftButton) {
                NotificationState.activate(root.notif);
            } else {
                NotificationState.remove(root.notif);
                root.notif.dismiss();
            }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.notifPad
        spacing: Style.spacing

        Item {
            id: thumb
            Layout.preferredWidth: compact ? Style.fontSize : Style.notifIconSize
            Layout.preferredHeight: compact ? Style.fontSize : Style.notifIconSize
            Layout.alignment: Qt.AlignTop
            readonly property bool compact: {
                const noActions = !root.deeds.length && !root.codes.length;
                return root.glyph.length > 0 && root.row && !root.row.body && noActions;
            }
            readonly property string sent: {
                if (!root.row)
                    return "";
                const image = root.row.image;
                if (image.indexOf("image://qsimage/") === 0)
                    return image;
                return Security.localImageUrl(image);
            }
            readonly property var sources: {
                const revision = DesktopEntries.applications.values.length;
                const names = Icons.candidates(root.row);
                const found = [thumb.sent];
                for (const name of names.themed)
                    found.push(Quickshell.iconPath(name, true));
                for (const name of names.entries) {
                    const entry = DesktopEntries.heuristicLookup(name);
                    if (entry && entry.icon) {
                        const icon = String(entry.icon);
                        const local = Security.localImageUrl(icon);
                        if (icon.charAt(0) === "/")
                            found.push(local);
                        else
                            found.push(Quickshell.iconPath(icon, true));
                    }
                }
                return found.filter((url, i) => url && found.indexOf(url) === i);
            }
            readonly property string sourcesKey: sources.join("\n")
            property int failed: 0
            onSourcesKeyChanged: failed = 0
            readonly property string best: sources[failed] || ""
            readonly property bool pictured: root.glyph.length === 0 && icon.status === Image.Ready
            readonly property bool photo: best !== "" && best === sent

            Rectangle {
                anchors.fill: parent
                visible: !thumb.pictured
                radius: Style.notifRadius
                color: Colors.bgSubtle
            }

            Text {
                anchors.centerIn: parent
                visible: !thumb.pictured
                text: {
                    const name = root.row ? root.row.source || root.row.app || "?" : "?";
                    return root.glyph || Array.from(name)[0].toUpperCase();
                }
                textFormat: Text.PlainText
                color: Colors.accent
                font.family: Style.fontFamily
                font.pixelSize: thumb.compact ? Style.fontSize : Style.notifIconSize * 0.65
            }

            Image {
                id: icon
                anchors.fill: parent
                visible: thumb.pictured
                asynchronous: true
                source: root.glyph ? "" : thumb.best
                sourceSize.width: Style.notifIconSize * 2
                sourceSize.height: Style.notifIconSize * 2
                fillMode: thumb.photo ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                onStatusChanged: if (status === Image.Error)
                    thumb.failed++
                layer.enabled: thumb.pictured && (thumb.photo || Icons.isSymbolic(thumb.best))
                layer.effect: MultiEffect {
                    colorization: Icons.isSymbolic(thumb.best) && !thumb.photo ? 1 : 0
                    colorizationColor: Colors.text
                    maskEnabled: thumb.photo
                    maskSource: photoMask
                }
            }

            Rectangle {
                id: photoMask
                anchors.fill: parent
                radius: Style.notifRadius
                visible: false
                layer.enabled: true
                color: "white"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(Style.spacing / 2)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: {
                        const summary = root.notif ? root.notif.summary : "";
                        return summary + (root.count > 1 ? "  \u00d7" + root.count : "");
                    }
                    textFormat: Text.PlainText
                    color: Colors.textHeading
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Item {
                    Layout.preferredWidth: Math.max(ageText.implicitWidth, Style.fontSize * 2)
                    Layout.preferredHeight: Math.max(ageText.implicitHeight, Style.fontSize * 2)
                    Text {
                        id: ageText
                        anchors.centerIn: parent
                        text: root.ageLabel()
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        opacity: root.hovered ? 0 : 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Style.duration(Style.motionFast)
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Colors.text
                        font.pixelSize: Style.fontSize * 1.4
                        opacity: root.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Style.duration(Style.motionFast)
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hovered
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t("notifications.dismiss")
                        onClicked: {
                            NotificationState.remove(root.notif);
                            root.notif.dismiss();
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.row && root.row.body.length > 0
                text: root.row ? root.row.bodyRich : ""
                color: Colors.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                // bodyRich is the permitted subset (Markup.render); raw sender markup
                // would let <img> fetch a file or a URL.
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: root.expanded || root.hovered ? 8 : 2
                onLinkActivated: link => Security.openExternalUrl(link)
                elide: Text.ElideRight
            }

            // Skip the implicit "default" action (invoked on body click) so the row stays clean.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(Style.spacing / 2)
                spacing: Style.spacing
                visible: root.notif && (root.deeds.length > 0 || root.codes.length > 0)

                Repeater {
                    model: root.codes

                    PanelButton {
                        required property string modelData
                        text: {
                            if (root.copiedCode === modelData)
                                return "✓";
                            return I18n.t("notifications.copyCode", modelData);
                        }
                        onClicked: {
                            NotificationState.copyCode(modelData);
                            root.copiedCode = modelData;
                            copiedTimer.restart();
                        }
                    }
                }

                Repeater {
                    model: root.deeds

                    PanelButton {
                        required property var modelData
                        required property int index
                        text: (root.selected ? index + 1 + " " : "") + modelData.label
                        onClicked: NotificationState.invokeDeed(root.notif, modelData)
                    }
                }
            }
        }
    }
}
