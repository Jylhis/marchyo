import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The Phase 4 lock surface: a compositor-level ext-session-lock-v1 lock with
// in-process PAM auth (Services/Lock owns the state machine). Instantiated
// exactly once, as a static child of ShellRoot in shell.qml — NEVER inside a
// Loader: destroying a WlSessionLock while locked leaves the compositor
// showing a solid color with no way back in through the shell.
//
// One WlSessionLockSurface is instantiated per screen automatically (no
// Variants needed); each renders the clock + password card, and the field on
// the focused output (Services/Screens) takes keyboard focus.
WlSessionLock {
    id: lockRoot

    locked: Lock.locked

    // Gate on `secure`, not `locked`: only once the compositor confirms every
    // screen is covered is it safe to start the PAM conversation and focus
    // the password field (upstream docs).
    onSecureChanged: {
        if (secure) {
            Lock.focusScreen = Screens.focusedName;
            Lock.onSecure();
        }
    }

    WlSessionLockSurface {
        id: surface

        // Opaque by construction: the surface color is what the compositor
        // shows if the QML scene fails — never bind a translucent value.
        color: Color.bg

        Rectangle {
            anchors.fill: parent
            color: Color.bg

            Column {
                anchors.centerIn: parent
                spacing: Style.spacing * 6

                // qmllint disable missing-property
                // Qt.formatDateTime is a valid QML global; qmllint's Qt type
                // model omits it (same suppression as Services/Clock.qml).
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(Clock.date, "HH:mm")
                    color: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize * 4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(Clock.date, "ddd d MMMM yyyy")
                    color: Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }
                // qmllint enable missing-property

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Lock.message.length > 0
                    text: Lock.message
                    color: Lock.messageIsError ? Color.statusErr : Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }

                Rectangle {
                    id: field

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Style.fontSize * 24
                    height: Style.fontSize * 2.5
                    color: Color.surface
                    radius: 0
                    border.width: 2
                    border.color: Lock.messageIsError ? Color.statusErr : Color.borderStrong

                    TextInput {
                        id: input

                        anchors.fill: parent
                        anchors.margins: Style.paddingH * 2
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Color.text
                        selectionColor: Color.accent
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        echoMode: Lock.maskInput ? TextInput.Password : TextInput.Normal
                        enabled: !Lock.busy
                        opacity: enabled ? 1 : 0.6

                        onAccepted: {
                            Lock.submit(input.text);
                            input.text = "";
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: input.text.length === 0 && input.enabled
                        text: "Password"
                        color: Color.textFaint
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                    }

                    // Any click claims keyboard focus for this screen's field
                    // (multi-monitor: focus otherwise follows the focused output).
                    MouseArea {
                        anchors.fill: parent
                        onClicked: input.forceActiveFocus()
                    }
                }
            }
        }

        // New PAM prompt or failure message: clear the field and (re)focus.
        // The message always changes between two identical prompts (a failure
        // line lands in between), so a retry reliably re-arms this handler.
        Connections {
            target: Lock
            function onMessageChanged() {
                input.text = "";
                if (Lock.focusScreen.length === 0 || surface.screen.name === Lock.focusScreen)
                    input.forceActiveFocus();
            }
        }
    }
}
