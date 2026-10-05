pragma Singleton
import QtQuick
import Quickshell
import qs.Commons
import "../Commons/LauncherProviders.js" as Providers

// Shared launcher state: which mode is open ("" = closed), the query text, and
// the provider that text routes to. Reached from the Hyprland keybinds via the
// shell IPC target; LauncherWindow and the Launcher/ providers bind to it. A
// singleton, so seat-global like PanelManager.
QtObject {
    id: root

    // "" = closed; otherwise "apps" | "emoji" | "clipboard".
    property string mode: ""

    readonly property bool open: mode !== ""

    // The launcher's query field, mirrored here by LauncherWindow.
    property string query: ""

    // Prefix routing (Commons/LauncherProviders.js): in apps mode "=" routes to
    // the calculator, ">theme" to themes, "#" to windows and "!" to power
    // actions; emoji and clipboard search the whole text. `provider` is the
    // active provider's id ("" while closed), `providerQuery` its query.
    readonly property var route: Providers.route(root.mode, root.query)
    readonly property string provider: root.route.provider
    readonly property string providerQuery: root.route.query

    onOpenChanged: if (!root.open)
        root.query = ""

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

    // Image counterpart of pasteText: put cliphist entry `id` back on the
    // clipboard as `mime` (wl-copy keeps serving it) and send Ctrl+V. Same
    // close-first rule; every value travels through argv.
    function pasteImage(id, mime) {
        Quickshell.execDetached(["sh", "-c", "\"$0\" decode \"$1\" | \"$2\" --type \"$3\" && sleep 0.25 && exec \"$4\" -M ctrl v -m ctrl", Config.cliphist, id, Config.wlCopy, mime, Config.wtype]);
    }
}
