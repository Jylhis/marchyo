import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/MenuModel.js" as MenuModel
import "../Commons/Paths.js" as Paths

// The keybinding cheat sheet, from ~/.config/marchyo/keybindings.json (written
// by modules/home/keybinds.nix), grouped by modifier plane. Search covers the
// description and the chord. Enter runs the bind's dispatcher through
// `hyprctl dispatch`; a bind whose action is not a plain dispatcher is listed
// but cannot run from here.
Provider {
    id: root

    providerId: "keys"
    selectOnEmpty: true
    compact: true
    emptyText: I18n.t("launcher.keysEmpty")

    readonly property var sheet: FileView {
        path: Paths.xdgDir(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"), "/.config") + "/marchyo/keybindings.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var allRows: {
        let parsed = [];
        try {
            parsed = JSON.parse(sheet.text() || "[]");
        } catch (e) {
            parsed = [];
        }
        return MenuModel.sheetRows(parsed).map(r => Object.assign({}, r, {
                "icon": "input-keyboard",
                "activate": () => {
                    if (r.dispatch === "")
                        return;
                    Launcher.close();
                    Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec \"$0\" dispatch \"$1\"", Config.hyprctl, r.dispatch]);
                }
            }));
    }

    results: MenuModel.searchSheet(root.allRows, root.query, (text, q) => Fuzzy.match(text, q))
}
