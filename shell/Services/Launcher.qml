pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// Shared launcher state: which mode is open ("" = closed). Reached from the
// Hyprland keybinds via the shell IPC target; LauncherWindow and the mode views
// bind to `mode`. A singleton, so seat-global like PanelManager.
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

    // Copy `text` and type it at the cursor. wtype targets the focused surface,
    // so callers close FIRST and the sleep lets the compositor restore focus to
    // the previous window (docs/gotchas.md). Text travels as $1 through argv, never
    // interpolated into the script, so clipboard content is not interpreted by sh.
    function pasteText(text) {
        Quickshell.clipboardText = text;
        Quickshell.execDetached(["sh", "-c", "sleep 0.25; exec \"$0\" \"$1\"", Config.wtype, text]);
    }
}
