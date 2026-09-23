import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.Commons

// The marchyo greeter: a Quickshell config run by greetd inside cage
// (modules/nixos/boot.nix). It speaks the greetd protocol through the native
// Quickshell.Services.Greetd client: createSession -> authMessage -> respond
// -> readyToLaunch -> launch("uwsm start hyprland-uwsm.desktop") — the same
// session command tuigreet launched. All state lives on this root object so
// the surface below is a pure view, the same rule the bar follows
// (shell/README.md): one clock, one state machine, one dumb surface.
//
// The surface is a FloatingWindow (a plain xdg-toplevel), NOT a PanelWindow:
// cage is a single-window kiosk with no wlr-layer-shell support, so a
// PanelWindow layer surface never maps and the screen stays black. cage
// fullscreens its one toplevel across the outputs (`-m extend`), which is the
// same shape regreet runs in under cage.
ShellRoot {
    id: root

    // Greeter-local geometry. Deliberately NOT added to Commons/Style.qml —
    // the bar/OSD/panel dimensions there are scaled by fontScale; a greeter
    // card is a fixed layout.
    readonly property int clockSize: 56
    readonly property int fieldWidth: 320
    readonly property int fieldHeight: 36
    readonly property int cardPad: 24
    readonly property int fieldFont: 16

    // ── session state ────────────────────────────────────────────────────────
    property string username: "" // two-way with the user field
    property string error: "" // sticky failure text, kept across PAM retries
    property string prompt: "" // current PAM prompt ("Password:")
    property bool awaitingResponse: false // a respond() is wanted
    property bool echoResponse: false // ...in clear text (fingerprint fallbacks etc.)
    property int failCount: 0 // guards the authFailure retry loop
    readonly property bool sessionActive: Greetd.state !== GreetdState.Inactive

    // The one clock for the whole config: never inside the Variants loop,
    // or every output gets its own (the ClockWidget lesson).
    readonly property var clock: SystemClock {
        precision: SystemClock.Minutes
    }

    // Last successful login's user, prefilled into the field. The NixOS
    // module tmpfiles-creates /var/cache/marchyo-greeter owned by greeter.
    property string lastUser: ""

    FileView {
        id: lastUserFile
        path: "/var/cache/marchyo-greeter/last-user"
        blockLoading: true
        printErrors: false // absent on first boot
        onLoaded: {
            root.lastUser = text().trim();
            root.username = root.lastUser;
        }
    }

    Component.onCompleted: if (!Greetd.available)
        root.error = "greetd socket unavailable"

    function beginLogin() {
        if (root.username.length === 0 || root.sessionActive)
            return;
        root.error = "";
        root.prompt = "";
        root.failCount = 0;
        Greetd.createSession(root.username);
    }

    function submit(password: string) {
        if (!root.awaitingResponse)
            return;
        root.awaitingResponse = false;
        Greetd.respond(password);
    }

    function cancel() {
        root.prompt = "";
        root.error = "";
        root.awaitingResponse = false;
        if (root.sessionActive)
            Greetd.cancelSession();
    }

    // One Connections on the root, not per surface: the protocol is
    // seat-global. (House style: readonly property var + Connections.)
    readonly property var greetdConn: Connections {
        target: Greetd

        // Handler params bind positionally; `error` is renamed isError so it
        // cannot be confused with the root's error property below.
        function onAuthMessage(message, isError, responseRequired, echo) {
            if (isError) {
                // Recoverable PAM error (e.g. a fingerprint misread): show it
                // and keep waiting on the current prompt.
                root.error = message;
                return;
            }
            root.prompt = message;
            if (responseRequired) {
                root.awaitingResponse = true;
                root.echoResponse = echo;
            }
        }

        function onAuthFailure(message) {
            root.failCount += 1;
            root.awaitingResponse = false;
            root.prompt = "";
            root.error = message !== "" ? message : "authentication failed";
            // greetd tore the failed session down; start a fresh one so the
            // next password attempt has a live session. After three straight
            // failures stop auto-retrying (an unknown user fails here too,
            // and auto-createSession would spin): back to the user field,
            // manual Enter restarts the cycle.
            if (root.failCount >= 3)
                return;
            if (Greetd.available && root.username.length > 0)
                Greetd.createSession(root.username);
        }

        function onReadyToLaunch() {
            // Remember the user for the next boot BEFORE launch() — greetd
            // expects the greeter to exit immediately. The FileView write is
            // async; if it loses that race the prefill is simply absent next
            // boot, which is benign.
            if (root.username !== root.lastUser) {
                root.lastUser = root.username;
                lastUserFile.setText(root.username);
            }
            Greetd.launch(Config.sessionCommand);
        }

        function onError(errorMessage) {
            root.awaitingResponse = false;
            root.error = errorMessage;
        }
    }

    // ── surface: the full-screen greeter window ──────────────────────────────
    //
    // A single FloatingWindow that cage fullscreens across every output. It
    // renders the card bound to the shared state above; cage grants it
    // keyboard focus as the sole toplevel, so no explicit focus grab is needed
    // beyond steering the caret between the user and secret fields.
    FloatingWindow {
        id: surface

        color: Color.bg

        Component.onCompleted: userField.forceActiveFocus()

        // Focus follows the protocol: a fresh prompt focuses the secret
        // field; losing the session hands focus back to the user field
        // (forceActiveFocus on an invisible item is a no-op).
        Connections {
            target: root
            function onAwaitingResponseChanged() {
                if (root.awaitingResponse)
                    secretField.forceActiveFocus();
                else
                    userField.forceActiveFocus();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Style.spacing * 4

            // Qt.formatDateTime is a valid QML global; qmllint's Qt type
            // model omits it (same guard as Services/Clock.qml).
            // qmllint disable missing-property
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.clock.date, "HH:mm")
                color: Color.textHeading
                font.family: Style.fontFamily
                font.pixelSize: root.clockSize
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.clock.date, "ddd d MMMM yyyy")
                color: Color.textFaint
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
            }
            // qmllint enable missing-property

            Rectangle {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.fieldWidth + root.cardPad * 2
                height: cardColumn.implicitHeight + root.cardPad * 2
                radius: Style.panelRadius
                color: Color.surface
                border.color: Color.border
                border.width: 1

                Column {
                    id: cardColumn
                    x: root.cardPad
                    y: root.cardPad
                    width: root.fieldWidth
                    spacing: Style.spacing * 2

                    Text {
                        text: "marchyo"
                        color: Color.accent
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }

                    // Username entry (idle state).
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.fieldWidth
                        height: root.fieldHeight
                        radius: Style.panelRadius
                        color: Color.bgSubtle
                        border.color: userField.activeFocus ? Color.accent : Color.borderStrong
                        border.width: 1
                        visible: !root.sessionActive

                        TextInput {
                            id: userField
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: Color.text
                            selectionColor: Color.selectionBg
                            font.family: Style.fontFamily
                            font.pixelSize: root.fieldFont
                            text: root.username
                            onTextChanged: root.username = text
                            onAccepted: root.beginLogin()
                            Keys.onEscapePressed: {
                                clear();
                                root.cancel();
                            }
                        }
                    }

                    // Prompt + secret entry (authenticating state). The
                    // field keeps its own text (no cross-surface binding to
                    // fight); onAccepted hands it straight to the protocol.
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.fieldWidth
                        spacing: Style.spacing
                        visible: root.awaitingResponse

                        Text {
                            width: parent.width
                            text: root.prompt
                            color: Color.textMuted
                            elide: Text.ElideRight
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                        }

                        Rectangle {
                            width: root.fieldWidth
                            height: root.fieldHeight
                            radius: Style.panelRadius
                            color: Color.bgSubtle
                            border.color: secretField.activeFocus ? Color.accent : Color.borderStrong
                            border.width: 1

                            TextInput {
                                id: secretField
                                anchors.fill: parent
                                anchors.margins: 8
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: Color.text
                                selectionColor: Color.selectionBg
                                font.family: Style.fontFamily
                                font.pixelSize: root.fieldFont
                                echoMode: root.echoResponse ? TextInput.Normal : TextInput.Password
                                onAccepted: {
                                    root.submit(text);
                                    clear();
                                }
                                Keys.onEscapePressed: root.cancel()
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.sessionActive && !root.awaitingResponse
                        text: "authenticating…"
                        color: Color.textFaint
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.fieldWidth
                        visible: root.error !== ""
                        text: root.error
                        color: Color.statusErr
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.sessionActive ? "esc cancel" : "enter log in"
                        color: Color.textFaint
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.panelGap * 2
            spacing: Style.spacing * 2

            PowerButton {
                label: "reboot"
                onClicked: Quickshell.execDetached([Config.systemctl, "reboot"])
            }
            PowerButton {
                label: "power off"
                onClicked: Quickshell.execDetached([Config.systemctl, "poweroff"])
            }
        }
    }

    component PowerButton: Rectangle {
        id: pb

        property string label: ""
        signal clicked

        width: pbLabel.implicitWidth + Style.paddingH * 4
        height: root.fieldHeight
        radius: Style.panelRadius
        color: pbMouse.containsMouse ? Color.surfaceRaised : Color.bgSubtle
        border.color: Color.border
        border.width: 1

        Text {
            id: pbLabel
            anchors.centerIn: parent
            text: pb.label
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }
}
