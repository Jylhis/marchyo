import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/MenuModel.js" as MenuModel
import "../Commons/LauncherProviders.js" as Providers
import "../Commons/Paths.js" as Paths

// The command menu: the entry tree from ~/.config/marchyo/menu.json (generated
// by marchyo.menu.entries) merged per key with menu.local.json, walked by
// Services/Launcher.menuRoute. A typed query searches everything below the open
// menu. `when` and `checked` guards run once, in one batched process, each time
// the menu opens, and are cached while it stays open. Provider entries list
// themes, fonts and the like with one `marchyo` command (MenuModel.js
// PROVIDER_SPECS); `apps` reads DesktopEntries.
Provider {
    id: root

    providerId: "menu"
    selectOnEmpty: true
    emptyText: root.model.children[""] ? I18n.t("launcher.noMatches") : I18n.t("launcher.menuEmpty")

    readonly property string configDir: Paths.xdgDir(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"), "/.config") + "/marchyo"

    readonly property var baseFile: FileView {
        path: root.configDir + "/menu.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var localFile: FileView {
        path: root.configDir + "/menu.local.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var model: MenuModel.build(MenuModel.mergeOverlay(MenuModel.parseEntries(baseFile.text()), MenuModel.parseEntries(localFile.text())))
    readonly property string route: MenuModel.resolveRoute(root.model, Launcher.menuRoute)
    readonly property var routeEntry: root.model.entries[root.route] || null
    readonly property string providerName: root.routeEntry && root.routeEntry.action === "provider" ? root.routeEntry.provider : ""
    readonly property string breadcrumbText: MenuModel.breadcrumb(root.model, root.route).map(b => b.label).join(" › ")

    // Guards: null until the batch ran, then { when, checked }.
    property var guardState: null
    property var guardList: []

    function runGuards() {
        root.guardState = null;
        guardProc.running = false;
        root.guardList = MenuModel.guardsFor(root.model, Object.keys(root.model.entries));
        if (root.guardList.length === 0) {
            root.guardState = {
                "when": {},
                "checked": {}
            };
            return;
        }
        guardProc.command = MenuModel.guardArgv(root.guardList);
        guardProc.running = true;
        guardTimeout.restart();
    }

    readonly property var guardProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                guardTimeout.stop();
                root.guardState = MenuModel.parseGuardOutput(root.guardList, text);
            }
        }
    }

    // A hung guard must not leave the menu empty: give up after 3 s.
    readonly property var guardTimeout: Timer {
        interval: 3000
        onTriggered: {
            guardProc.running = false;
            if (root.guardState === null)
                root.guardState = {
                    "when": {},
                    "checked": {}
                };
        }
    }

    // Provider items for the open provider route.
    property var items: []
    property bool loading: false

    readonly property var listProc: Process {
        stdout: StdioCollector {
            readonly property int maxChars: 512 * 1024
            onStreamFinished: {
                const spec = MenuModel.PROVIDER_SPECS[root.providerName];
                root.items = spec && text.length <= maxChars ? spec.parse(text) : [];
                root.loading = false;
            }
        }
    }

    function loadProvider() {
        root.items = [];
        listProc.running = false;
        const spec = MenuModel.PROVIDER_SPECS[root.providerName];
        if (!spec) {
            root.loading = false;
            return;
        }
        root.loading = true;
        listProc.command = [Config.marchyo].concat(spec.list);
        listProc.running = true;
    }

    onActiveChanged: if (root.active)
        root.runGuards()
    onProviderNameChanged: if (root.active)
        root.loadProvider()

    function detach(argv) {
        Quickshell.execDetached(argv);
    }

    // The menu goes away before the action runs so a capture never sees it.
    function runLater(argv) {
        Launcher.close();
        root.detach(["sh", "-c", "sleep 0.2; exec \"$@\"", "sh"].concat(argv));
    }

    function activateRow(r) {
        if (r.disabled)
            return;
        if (r.submenu) {
            Launcher.menuInto(r.id);
        } else if (r.action === "exec") {
            root.runLater(["sh", "-c", r.target]);
        } else if (r.action === "terminal") {
            root.runLater([Config.marchyo, "launch", "floating-terminal", "sh", "-c", r.target]);
        } else if (r.action === "launcher") {
            Launcher.openAs(r.target);
        }
    }

    function menuRow(r) {
        const out = Object.assign({}, r);
        out.trailing = r.checked ? "✓" : (r.submenu ? "›" : "");
        out.activate = () => root.activateRow(r);
        return out;
    }

    function itemRow(spec, it) {
        return {
            "title": it.title,
            "subtitle": it.subtitle,
            "icon": spec.icon,
            "trailing": it.checked ? "✓" : "",
            "checked": it.checked,
            "score": 0,
            "positions": [],
            "activate": () => {
                Launcher.close();
                root.detach([Config.marchyo].concat(it.argv));
            }
        };
    }

    function appRows() {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        apps.sort((a, b) => a.name.localeCompare(b.name));
        return apps.map(a => ({
                    "title": a.name,
                    "subtitle": a.comment || "",
                    "icon": a.icon,
                    "trailing": "",
                    "score": 0,
                    "positions": [],
                    "activate": () => {
                        Launcher.close();
                        a.execute();
                    }
                }));
    }

    readonly property var rows: {
        if (root.providerName === "apps")
            return root.appRows();
        if (root.providerName !== "") {
            const spec = MenuModel.PROVIDER_SPECS[root.providerName];
            return spec ? root.items.map(it => root.itemRow(spec, it)) : [];
        }
        return null;
    }

    results: {
        const q = root.query.trim();
        if (root.rows !== null)
            return Providers.rank(root.rows, q, (text, query) => Fuzzy.match(text, query));
        if (root.guardState === null && root.guardList.length > 0)
            return [];
        if (q === "")
            return MenuModel.levelRows(root.model, root.route, root.guardState).map(r => root.menuRow(r));
        return MenuModel.searchRows(root.model, root.route, q, root.guardState, (text, query) => Fuzzy.match(text, query)).map(r => root.menuRow(r));
    }
}
