pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Commons
import "../Commons/SessionLock.js" as SessionLock

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

    // Drives WlSessionLock.locked in LockScreen (gated by screensReady there).
    property bool locked: false

    // True once at least one real output has been stable for screenSettleMs.
    // LockScreen requests the compositor lock only then: a WlSessionLock that
    // locks while outputs are being replaced asks for a lock surface on an
    // output Hyprland has already torn down, a fatal protocol error.
    readonly property int screenSettleMs: 300
    property bool screensReady: false

    readonly property var screenSettle: Timer {

        interval: root.screenSettleMs
        onTriggered: root.screensReady = Screens.realCount > 0
    }

    function handleScreensChanged() {
        root.screensReady = false;
        root.screenSettle.restart();
        // A monitor still coming up has no workspace and cannot answer yet.
        root.strandedRetry.rearm();
        root.checkStranded();
    }

    readonly property var screenWatch: Connections {
        target: Quickshell

        function onScreensChanged() {
            root.handleScreensChanged();
        }
    }

    // Stranded-lock recovery. ext-session-lock outlives its client: if the
    // shell exits while locked, Hyprland keeps the session locked, and a new
    // shell starts with locked = false. Read the compositor's state and take
    // the lock back (misc.allow_session_lock_restore permits it). marchyo-shell
    // is the only locker when the shell is enabled, so a held lock is its own.
    property bool strandedResolved: false

    function checkStranded() {
        if (root.strandedResolved || root.strandedProbe.running)
            return;
        if (root.locked) {
            root.strandedResolved = true;
            return;
        }
        root.strandedProbe.running = true;
    }

    readonly property var strandedProbe: Process {

        command: [Config.hyprctl, "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const state = SessionLock.lockState(text);
                if (state === "unknown")
                    return; // strandedRetry asks again
                root.strandedResolved = true;
                if (state === "locked" && !root.locked) {
                    console.warn("Lock: compositor holds an orphaned session lock; recovering");
                    root.lock();
                }
            }
        }
    }

    // Covers the compositor settling after a restart; screen changes re-arm it.
    readonly property var strandedRetry: Timer {

        readonly property int budget: 20
        property int remaining: budget

        function rearm() {
            if (!root.strandedResolved)
                remaining = budget;
        }

        interval: 500
        repeat: true
        running: !root.strandedResolved && remaining > 0
        onTriggered: {
            remaining -= 1;
            root.checkStranded();
        }
    }

    Component.onCompleted: {
        root.screenSettle.start();
        root.checkStranded();
    }

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
        root.failureTimer.stop();
        root.failed = false;
        root.failureText = "";
    }

    function registerFailure(text) {
        root.failureText = text;
        root.failed = true;
        root.failureCount += 1;
        root.failureTimer.restart();
    }

    readonly property var failureTimer: Timer {

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
        if (!root.pam.active)
            root.pam.start();
    }

    // The field's Enter handler. Empty input is ignored (hyprlock's
    // ignore_empty_input parity); after a terminal PAM error the next Enter
    // restarts the conversation instead of responding into a dead session.
    function submit(text) {
        if (root.busy || text.length === 0)
            return;
        if (!root.pam.active) {
            root.pam.start();
            return;
        }
        if (!root.pam.responseRequired)
            return;
        root.busy = true;
        root.pam.respond(text);
    }

    readonly property var pam: PamContext {

        // The stock NixOS login stack (Quickshell's default); pam_unix and an
        // optional fprintd factor both flow through the message protocol.
        config: "login"

        onPamMessage: {
            // pamMessage carries no parameters; read the just-updated state.
            root.message = root.pam.message;
            root.messageIsError = root.pam.messageIsError;
            if (root.pam.responseRequired)
                root.maskInput = !root.pam.responseVisible;
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
                root.pam.start(); // fresh conversation for the retry
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
