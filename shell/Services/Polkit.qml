pragma Singleton
import QtQuick
import Quickshell.Services.Polkit

// The session's polkit authentication agent (replaces hyprpolkitagent when the
// shell is on; see modules/home/marchyo-shell.nix) and the state the dialog
// (Polkit/PolkitDialog.qml) renders. Quickshell's PolkitAgent registers with
// the polkit daemon on load, queues incoming requests, and runs one PAM
// conversation per request; this singleton only adapts its AuthFlow for the
// view and tracks the submit/failure UI state.
//
// Only one agent can be registered per session. If another one already holds
// the slot (a dev instance next to the store shell, or hyprpolkitagent on a
// host without the cutover) registration fails, `registered` stays false, and
// the dialog never shows.
QtObject {
    id: root

    readonly property var agent: PolkitAgent {}

    readonly property bool registered: root.agent.isRegistered
    readonly property var flow: root.agent.flow
    // A request is on screen from authenticationRequestStarted until it
    // succeeds, is cancelled (by the user or the daemon), or is dismissed.
    readonly property bool active: root.agent.isActive && root.flow !== null

    readonly property string message: root.flow ? root.flow.message : ""
    readonly property string iconName: root.flow ? root.flow.iconName : ""
    readonly property string actionId: root.flow ? root.flow.actionId : ""
    // The identity the password is asked for ("Authenticate as …"). polkit
    // picks the first allowed identity; admin groups expand to their members.
    readonly property string identityName: {
        const id = root.flow ? root.flow.selectedIdentity : null;
        return id ? (id.displayName || "") : "";
    }
    readonly property bool responseRequired: root.flow ? root.flow.isResponseRequired : false
    readonly property string prompt: root.flow ? root.flow.inputPrompt : ""
    readonly property bool maskInput: root.flow ? !root.flow.responseVisible : true
    readonly property string supplementary: root.flow ? root.flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: root.flow ? root.flow.supplementaryIsError : false

    // True between submit() and the next PAM turn, so the field ignores Enter.
    property bool busy: false
    // Bumps once per rejected password so the dialog can shake and clear.
    property int failureCount: 0
    property bool failed: false

    function submit(response: string): void {
        if (!root.flow || !root.flow.isResponseRequired || root.busy)
            return;
        root.busy = true;
        root.flow.submit(response);
    }

    function cancel(): void {
        if (root.flow)
            root.flow.cancelAuthenticationRequest();
    }

    // Each request starts with a clean slate.
    onFlowChanged: {
        root.busy = false;
        root.failed = false;
    }

    readonly property var flowConn: Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired)
                root.busy = false;
        }
        function onAuthenticationFailed() {
            root.busy = false;
            root.failed = true;
            root.failureCount++;
        }
        function onAuthenticationSucceeded() {
            root.busy = false;
        }
        function onAuthenticationRequestCancelled() {
            root.busy = false;
        }
    }
}
