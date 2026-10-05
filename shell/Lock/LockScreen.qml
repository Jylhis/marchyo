import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The lock surface: a compositor-level ext-session-lock-v1 lock with in-process
// PAM auth (Services/Lock owns the state machine). Instantiated exactly once, as
// a static child of ShellRoot in shell.qml, NEVER inside a Loader: destroying a
// WlSessionLock while locked leaves the compositor showing a solid color with no
// way back in through the shell.
//
// One WlSessionLockSurface is instantiated per screen automatically; each renders
// the clock, and the output owning the card (Lock.focusScreen) renders the
// password field and takes keyboard focus. Every surface absorbs all pointer
// and keyboard input; a press or keystroke on another output moves the card.
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

        // The output that owns the interactive card. Every output stays locked
        // (protocol), but only one shows the password field.
        readonly property bool isFocused: Lock.focusScreen.length === 0 || surface.screen.name === Lock.focusScreen

        // Opaque by construction: the surface color is what the compositor shows
        // if the QML scene fails, never bind a translucent value.
        color: Color.bg

        // Shake geometry for a rejected password (local: lock-only, not themed).
        readonly property int shakeDistance: Style.fontSize
        readonly property int shakeStep: Math.max(1, Math.round(Style.animationDuration / 3))

        // Move the card to this output and give its field keyboard focus.
        function claimCard() {
            if (!surface.isFocused)
                Lock.focusScreen = surface.screen.name;
            input.forceActiveFocus();
        }

        // Pointer absorption: every button, hover, wheel and pinch on this
        // output terminates here, so nothing reaches a surface beneath or
        // falls through to compositor bindings. Any press (re)claims the card
        // for this output. Declared before the backdrop so the field's own
        // MouseArea draws on top.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: surface.claimCard()
            onWheel: wheel => {
                wheel.accepted = true;
            }
        }

        PinchHandler {
            target: null
        }

        Rectangle {
            id: backdrop

            anchors.fill: parent
            color: Color.bg

            // Keyboard absorption: keys the field does not consume (Tab,
            // Escape, function keys) and every key on an output without the
            // card bubble here. All are swallowed; a key on another output
            // moves the card to it (the compositor routed the keyboard there)
            // and forwards a printable character so the first keystroke is
            // not lost.
            focus: true
            Keys.onPressed: event => {
                event.accepted = true;
                const moved = !surface.isFocused;
                surface.claimCard();
                const printable = event.text.length > 0 && event.text.charCodeAt(0) >= 32 && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
                if (moved && printable && !input.readOnly)
                    input.insert(input.cursorPosition, event.text);
            }

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

                // The failure line holds for Lock.failureResetMs over the
                // fresh PAM prompt, then the prompt shows through again.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: surface.isFocused && text.length > 0
                    text: Lock.failed ? Lock.failureText : Lock.message
                    color: Lock.failed || Lock.messageIsError ? Color.statusErr : Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }

                Rectangle {
                    id: field

                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: surface.isFocused
                    width: Style.fontSize * 24
                    height: Style.fontSize * 2.5
                    color: Color.surface
                    radius: 0
                    border.width: 2
                    border.color: Lock.failed || Lock.messageIsError ? Color.statusErr : Color.borderStrong

                    // Shake offset: a Translate leaves the Column's anchoring
                    // intact. Driven only by the explicit animation below (no
                    // Behavior), which always settles back at 0.
                    transform: Translate {
                        id: shakeShift
                    }

                    SequentialAnimation {
                        id: shake

                        NumberAnimation {
                            target: shakeShift
                            property: "x"
                            to: -surface.shakeDistance
                            duration: surface.shakeStep
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: shakeShift
                            property: "x"
                            to: surface.shakeDistance
                            duration: surface.shakeStep * 2
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeShift
                            property: "x"
                            to: -surface.shakeDistance / 2
                            duration: surface.shakeStep * 2
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeShift
                            property: "x"
                            to: 0
                            duration: surface.shakeStep
                            easing.type: Easing.InQuad
                        }
                    }

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
                        // readOnly, not enabled: a disabled item drops active
                        // focus, and keystrokes during PAM would then escape
                        // the field.
                        readOnly: Lock.busy
                        opacity: readOnly ? 0.6 : 1

                        // Focus always returns to the field on the card's
                        // output (deferred so a focus hand-off in flight
                        // settles first).
                        onActiveFocusChanged: {
                            if (!activeFocus && surface.isFocused && lockRoot.secure)
                                Qt.callLater(() => {
                                    if (surface.isFocused && !input.activeFocus)
                                        input.forceActiveFocus();
                                });
                        }

                        onAccepted: {
                            Lock.submit(input.text);
                            input.text = "";
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: input.text.length === 0 && !input.readOnly
                        text: "Password"
                        color: Color.textFaint
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                    }

                    // Any press claims keyboard focus for this screen's field
                    // (multi-monitor: focus otherwise follows the focused output).
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onPressed: surface.claimCard()
                    }
                }
            }
        }

        // New PAM prompt or failure message: clear the field and (re)focus.
        // The message always changes between two identical prompts (a failure
        // line lands in between), so a retry reliably re-arms this handler.
        // A rejected password additionally shakes the field on every output
        // (only the card's output has it visible).
        Connections {
            target: Lock
            function onMessageChanged() {
                input.text = "";
                if (surface.isFocused)
                    input.forceActiveFocus();
            }
            function onFailureCountChanged() {
                input.text = "";
                shake.restart();
                if (surface.isFocused)
                    input.forceActiveFocus();
            }
            function onLockedChanged() {
                if (!Lock.locked) {
                    shake.stop();
                    shakeShift.x = 0;
                }
            }
        }
    }
}
