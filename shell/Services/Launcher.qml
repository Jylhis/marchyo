pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// Shared launcher state: which mode is open ("" = closed). The Hyprland
// keybinds reach this through the shell IPC target (toggleLauncher /
// openLauncher / closeLauncher in shell.qml); LauncherWindow binds its
// visibility and the mode views bind their `visible` to `mode`. A
// singleton, so seat-global by construction — the same shape PanelManager
// has for the panels.
QtObject {
    id: root

    // "" = closed; otherwise "apps" | "emoji" | "clipboard".
    property string mode: ""

    readonly property bool open: mode !== ""

    function openAs(mode) {
        root.mode = mode;
    }

    function toggle(mode) {
        root.mode = root.mode === mode ? "" : mode;
    }

    function close() {
        root.mode = "";
    }

    // Copy `text` to the clipboard and type it at the cursor, vicinae-style.
    //
    // wtype delivers to whichever surface holds keyboard focus — which is
    // the launcher while it is open — so callers close FIRST; the sleep
    // gives the compositor a beat to restore focus to the previous window
    // (see docs/gotchas.md). The text travels as $1 through argv, never
    // interpolated into the script, so clipboard content cannot be
    // interpreted by sh.
    function pasteText(text) {
        Quickshell.clipboardText = text;
        Quickshell.execDetached(["sh", "-c", "sleep 0.25; exec \"$0\" \"$1\"", Config.wtype, text]);
    }
}
