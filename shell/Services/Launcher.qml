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

    // "" = closed; otherwise "apps" | "emoji" | "clipboard" | "theme" | "font"
    // | "menu" | "keys" | "dmenu".
    property string mode: ""

    // Command menu: the open menu id ("" = the root), changed by openMenu(),
    // menuInto() and menuUp() (Launcher/MenuProvider reads it).
    property string menuRoute: ""

    // dmenu mode: the request file `marchyo menu select|input` wrote
    // (Launcher/DmenuProvider answers it).
    property string dmenuPath: ""

    readonly property bool open: mode !== ""

    // The launcher's query field, mirrored here by LauncherWindow.
    property string query: ""

    // Prefix routing (Commons/LauncherProviders.js): in apps mode "=" routes to
    // the calculator, ">theme" to themes, ">font" to fonts, "#" to windows and "!" to power
    // actions; emoji and clipboard search the whole text. A launcher plugin's
    // prefix (Commons/PluginIndex) routes to that plugin, whose provider id is
    // its plugin id. `provider` is the active provider's id ("" while closed),
    // `providerQuery` its query.
    readonly property var route: Providers.route(root.mode, root.query, PluginIndex.launcherPrefixes())
    readonly property string provider: root.route.provider
    readonly property string providerQuery: root.route.query

    onOpenChanged: if (!root.open) {
        root.query = "";
        root.menuRoute = "";
    }

    function openMenu(route) {
        root.menuRoute = route;
        root.query = "";
        root.mode = "menu";
        return true;
    }

    // Closes the menu when it shows `route`, else opens it there.
    function toggleMenu(route) {
        if (root.mode === "menu" && root.menuRoute === route) {
            root.close();
            return false;
        }
        return root.openMenu(route);
    }

    function menuInto(id) {
        root.query = "";
        root.menuRoute = id;
    }

    // One level up; false at the root.
    function menuUp() {
        if (root.menuRoute === "")
            return false;
        const i = root.menuRoute.lastIndexOf(".");
        root.query = "";
        root.menuRoute = i < 0 ? "" : root.menuRoute.slice(0, i);
        return true;
    }

    function openDmenu(path) {
        root.dmenuPath = path;
        root.query = "";
        root.mode = "dmenu";
    }

    function openAs(mode) {
        root.mode = mode;
    }

    // Returns whether `mode` is open afterwards.
    function toggle(mode) {
        root.mode = root.mode === mode ? "" : mode;
        return root.open;
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
