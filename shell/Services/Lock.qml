pragma Singleton
import QtQuick
import Quickshell.Services.Pam

// Seat-global lock state + PAM auth machine for the lock surface (rendered by
// Lock/LockScreen.qml; driven over IPC from shell.qml).
//
// Safety (ext-session-lock-v1): if the shell dies or this lock is destroyed
// while locked, the compositor keeps the session locked with a solid color.
// So `locked = false` is set in exactly ONE place (PamResult.Success below), and
// LockScreen must never live inside a Loader or anything that could tear it down
// mid-lock.
QtObject {
    id: root

    // Drives WlSessionLock.locked in LockScreen.
    property bool locked: false

    // Screen name whose password field takes keyboard focus once the lock is
    // secure (set by LockScreen from Screens.focusedName on secureChanged).
    property string focusScreen: ""

    // Latest PAM conversation line: the prompt when a response is required,
    // otherwise informational text or an error.
    property string message: ""
    property bool messageIsError: false

    // Mask the field unless PAM says the response is visible.
    property bool maskInput: true

    // True between respond() and completed() so the field ignores Enter.
    property bool busy: false

    // Failed-attempt state: `failed` holds for failureResetMs after a rejected
    // password (the surface shows failureText over the PAM prompt and tints the
    // field), and `failureCount` bumps once per rejection so every surface can
    // replay its shake even when two failures land inside one reset window.
    readonly property int failureResetMs: 3000
    property bool failed: false
    property string failureText: ""
    property int failureCount: 0

    function clearFailure() {
        failureTimer.stop();
        root.failed = false;
        root.failureText = "";
    }

    function registerFailure(text) {
        root.failureText = text;
        root.failed = true;
        root.failureCount += 1;
        failureTimer.restart();
    }

    readonly property var failureTimer: Timer {
        id: failureTimer

        interval: root.failureResetMs
        onTriggered: {
            root.failed = false;
            root.failureText = "";
        }
    }

    function lock() {
        if (root.locked)
            return;
        root.message = "";
        root.messageIsError = false;
        root.busy = false;
        root.clearFailure();
        root.locked = true;
    }

    // LockScreen calls this once every screen is covered (WlSessionLock.secure),
    // the gate before the PAM conversation starts and the field is focused.
    function onSecure() {
        if (!pam.active)
            pam.start();
    }

    // The field's Enter handler. Empty input is ignored (hyprlock's
    // ignore_empty_input parity); after a terminal PAM error the next Enter
    // restarts the conversation instead of responding into a dead session.
    function submit(text) {
        if (root.busy || text.length === 0)
            return;
        if (!pam.active) {
            pam.start();
            return;
        }
        if (!pam.responseRequired)
            return;
        root.busy = true;
        pam.respond(text);
    }

    readonly property var pam: PamContext {
        id: pam

        // The stock NixOS login stack (Quickshell's default); pam_unix and an
        // optional fprintd factor both flow through the message protocol.
        config: "login"

        onPamMessage: {
            // pamMessage carries no parameters; read the just-updated state.
            root.message = pam.message;
            root.messageIsError = pam.messageIsError;
            if (pam.responseRequired)
                root.maskInput = !pam.responseVisible;
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                // The ONLY unlock path in the shell.
                root.locked = false;
                root.message = "";
                root.messageIsError = false;
                root.clearFailure();
            } else if (result === PamResult.Failed) {
                root.message = "Authentication failed";
                root.messageIsError = true;
                root.registerFailure(root.message);
                pam.start(); // fresh conversation for the retry
            } else if (result === PamResult.MaxTries) {
                root.message = "Too many attempts — wait, then press Enter";
                root.messageIsError = true;
                root.registerFailure(root.message);
            } else {
                // PamResult.Error: the session is dead; the next Enter
                // (submit -> start) begins a new one.
                root.message = "Authentication error";
                root.messageIsError = true;
            }
        }
    }
}
