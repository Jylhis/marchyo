pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/LauncherProviders.js" as Providers
import "../Commons/LauncherRoutes.js" as Routes

// Shared launcher state: which mode is open ("" = closed), the query text, and
// the provider that text routes to. Reached from the Hyprland keybinds via the
// shell IPC target; LauncherWindow and the Launcher/ providers bind to it. A
// singleton, so seat-global like PanelManager. A plugin that replaces a
// launcher role (`launcher`, `launcher.emoji`, `launcher.clipboard`) gets the
// modes of that role: the functions below summon it (Commons/LauncherRoutes.js)
// and the native mode never opens.
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

    // True while the native launcher window serves some mode: a launcher role
    // that no plugin replaces.
    readonly property var _roles: ["launcher", "launcher.emoji", "launcher.clipboard"]
    readonly property bool nativeWindow: root._roles.some(r => PluginIndex.replacementFor(r) === "")

    // Hiding the menu plugin cancels its pending dmenu request, so a caller
    // of `marchyo menu select|input` is answered before the menu is reused.
    function _hideReplacements(keep) {
        for (const r of root._roles) {
            const id = PluginIndex.replacementFor(r);
            if (id !== "" && id !== keep && PluginHost.isOpen(id))
                PluginHost.hide(id);
        }
    }

    function _replacement(mode, route) {
        return Routes.target(mode, route || "", role => PluginIndex.replacementFor(role));
    }

    // Opens (or toggles) the replacement `t`; returns whether it is now open.
    function _summon(t, toggle) {
        root.mode = "";
        root._hideReplacements(toggle && t.plugin ? t.plugin : "");
        if (t.panel) {
            if (toggle)
                PanelManager.toggle(t.panel);
            else
                PanelManager.open(t.panel);
            return PanelManager.openId === t.panel;
        }
        const payload = JSON.stringify(t.payload);
        if (toggle)
            PluginHost.toggle(t.plugin, payload);
        else
            PluginHost.summon(t.plugin, payload);
        return PluginHost.isOpen(t.plugin) || !toggle;
    }

    function openMenu(route) {
        const t = root._replacement("menu", route);
        if (t !== null)
            return root._summon(t, false);
        root._hideReplacements("");
        root.menuRoute = route;
        root.query = "";
        root.mode = "menu";
        return true;
    }

    // Closes the menu when it shows `route`, else opens it there. A replacing
    // menu closes on any open route.
    function toggleMenu(route) {
        const t = root._replacement("menu", route);
        if (t !== null)
            return root._summon(t, true);
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

    readonly property var _dmenuFile: FileView {
        blockAllReads: true
        printErrors: false
    }

    // A replacing menu answers the request itself, in the files `marchyo menu`
    // polls, so the CLI sees the same answer as from the native mode.
    function openDmenu(path) {
        const plugin = PluginIndex.replacementFor("launcher");
        if (plugin === "") {
            root._hideReplacements("");
            root.dmenuPath = path;
            root.query = "";
            root.mode = "dmenu";
            return;
        }
        if (!Routes.dmenuPathOk(path, Quickshell.env("XDG_RUNTIME_DIR") || ""))
            return;
        root._dmenuFile.path = path;
        root._dmenuFile.reload();
        let req = {};
        try {
            req = JSON.parse(root._dmenuFile.text() || "{}");
        } catch (e) {
            req = {};
        }
        root.close();
        PluginHost.summon(plugin, JSON.stringify(Routes.dmenuPayload(req, path)));
    }

    function openAs(mode) {
        const t = root._replacement(mode, "");
        if (t !== null) {
            root._summon(t, false);
            return;
        }
        root._hideReplacements("");
        root.mode = mode;
    }

    // Returns whether `mode` is open afterwards.
    function toggle(mode) {
        const t = root._replacement(mode, "");
        if (t !== null)
            return root._summon(t, true);
        root._hideReplacements("");
        root.mode = root.mode === mode ? "" : mode;
        return root.open;
    }

    function close() {
        root.mode = "";
        root._hideReplacements("");
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
