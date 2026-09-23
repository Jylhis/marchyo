pragma Singleton
import QtQuick
import Quickshell.Services.Pam

// Seat-global lock state + the PAM auth machine for the Phase 4 lock surface
// (Lock/LockScreen.qml renders it; shell.qml exposes `shell lock` / `shell
// lockState` over IPC for the SUPER+L bind and hypridle's lock points).
//
// Safety (ext-session-lock-v1): if the shell dies or this lock is destroyed
// while locked, the compositor keeps the session locked with a solid color.
// `locked = false` is therefore set in exactly ONE place — PamResult.Success
// below — and LockScreen must never live inside a Loader or anything else
// that could tear it down mid-lock.
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

    function lock() {
        if (root.locked)
            return;
        root.message = "";
        root.messageIsError = false;
        root.busy = false;
        root.locked = true;
    }

    // LockScreen calls this once the compositor confirms every screen is
    // covered (WlSessionLock.secure) — the gate before the PAM conversation
    // starts and the password field is focused.
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
            } else if (result === PamResult.Failed) {
                root.message = "Authentication failed";
                root.messageIsError = true;
                pam.start(); // fresh conversation for the retry
            } else if (result === PamResult.MaxTries) {
                root.message = "Too many attempts — wait, then press Enter";
                root.messageIsError = true;
            } else {
                // PamResult.Error: the session is dead; the next Enter
                // (submit -> start) begins a new one.
                root.message = "Authentication error";
                root.messageIsError = true;
            }
        }
    }
}
