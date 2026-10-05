import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The polkit authentication dialog: a full-screen overlay layer (scrim plus a
// centered card) on the focused output, shown while Services/Polkit has an
// active request. It holds exclusive keyboard focus while open. Enter submits
// the password, Escape or Cancel cancels the request. A click outside the card
// does nothing, so a stray click never silently cancels an authentication.
PanelWindow {
    id: root

    visible: Polkit.active
    screen: Screens.byName(Screens.focusedName)
    color: Qt.alpha(Color.scrim, 0.4)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    // Hyprland layer rules (blur, animation) match the "marchyo:" prefix.
    WlrLayershell.namespace: "marchyo:polkit"
    WlrLayershell.keyboardFocus: Polkit.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    readonly property int shakeDistance: Style.fontSize
    readonly property int shakeStep: Math.max(1, Math.round(Style.animationDuration / 3))

    onVisibleChanged: if (visible) {
        input.text = "";
        input.forceActiveFocus();
        focusRetry.restart();
    }

    // Absorbs pointer input outside the card (no click-to-dismiss).
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.launcherWidth, parent.width - 2 * Style.panelGap)
        implicitHeight: column.implicitHeight + 2 * Style.panelPad
        radius: Style.panelRadius
        color: Qt.alpha(Color.bg, Style.surfaceAlpha)
        border.color: Polkit.failed ? Color.statusErr : Color.border
        border.width: 1

        transform: Translate {
            id: shakeShift
        }

        SequentialAnimation {
            id: shake
            NumberAnimation {
                target: shakeShift
                property: "x"
                to: -root.shakeDistance
                duration: root.shakeStep
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeShift
                property: "x"
                to: root.shakeDistance
                duration: root.shakeStep * 2
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeShift
                property: "x"
                to: 0
                duration: root.shakeStep
                easing.type: Easing.InQuad
            }
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.panelPad
            spacing: Style.spacing * 2

            Text {
                width: parent.width
                text: "Authentication required"
                color: Color.textHeading
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                font.bold: true
            }

            Text {
                width: parent.width
                text: Polkit.message
                color: Color.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: Polkit.identityName.length > 0
                text: "Authenticating as " + Polkit.identityName
                color: Color.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: Polkit.actionId.length > 0
                text: Polkit.actionId
                color: Color.textFaint
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                elide: Text.ElideMiddle
            }

            // PAM's supplementary line (errors, "Password:" hints, second
            // factor instructions), or the failure notice after a rejection.
            Text {
                width: parent.width
                visible: text.length > 0
                text: Polkit.supplementary.length > 0 ? Polkit.supplementary : (Polkit.failed ? "Authentication failed, try again" : "")
                color: Polkit.supplementaryIsError || Polkit.failed ? Color.statusErr : Color.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Rectangle {
                width: parent.width
                height: Style.fontSize * 2.5
                color: Color.surface
                border.width: 1
                border.color: Polkit.failed ? Color.statusErr : (input.activeFocus ? Color.accent : Color.border)

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: Style.paddingH * 2
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Color.text
                    selectionColor: Color.selectionBg
                    selectedTextColor: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    echoMode: Polkit.maskInput ? TextInput.Password : TextInput.Normal
                    // readOnly, not enabled: a disabled item drops active focus.
                    readOnly: Polkit.busy || !Polkit.responseRequired
                    opacity: readOnly ? 0.6 : 1

                    Keys.onEscapePressed: Polkit.cancel()
                    onAccepted: {
                        Polkit.submit(input.text);
                        input.text = "";
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.paddingH * 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: Polkit.busy ? "Checking…" : (Polkit.prompt.length > 0 ? Polkit.prompt : "Password")
                    color: Color.textFaint
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Style.spacing * 2

                Repeater {
                    model: [
                        {
                            label: "Cancel",
                            primary: false
                        },
                        {
                            label: "Authenticate",
                            primary: true
                        }
                    ]

                    Rectangle {
                        id: button
                        required property var modelData
                        readonly property bool enabledAction: !button.modelData.primary || (Polkit.responseRequired && !Polkit.busy)
                        width: label.implicitWidth + 2 * Style.panelPad
                        height: Style.panelRowHeight
                        radius: Style.panelRadius
                        color: button.modelData.primary ? (mouse.containsMouse && button.enabledAction ? Color.accentHover : Color.accent) : (mouse.containsMouse ? Color.surfaceRaised : Color.bgSubtle)
                        opacity: button.enabledAction ? 1 : 0.6
                        border.color: Color.border
                        border.width: button.modelData.primary ? 0 : 1

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: button.modelData.label
                            color: button.modelData.primary ? Color.bg : Color.text
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!button.modelData.primary) {
                                    Polkit.cancel();
                                } else if (button.enabledAction) {
                                    Polkit.submit(input.text);
                                    input.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A rejected password: clear the field, shake the card, keep focus.
    Connections {
        target: Polkit
        function onFailureCountChanged() {
            input.text = "";
            shake.restart();
            input.forceActiveFocus();
        }
        function onResponseRequiredChanged() {
            if (Polkit.responseRequired)
                input.forceActiveFocus();
        }
    }

    // Map-then-focus retry (LauncherWindow idiom): the first forceActiveFocus
    // can land before the surface accepts keyboard focus.
    Timer {
        id: focusRetry
        interval: 50
        onTriggered: if (root.visible)
            input.forceActiveFocus()
    }
}
