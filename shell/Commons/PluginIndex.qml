pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "PluginManifest.js" as PM
import "Paths.js" as Paths

// Index of the shell plugins baked into this store shell (the build-time
// Option A model). packages/marchyo-shell/package.nix copies each declared
// plugin into share/marchyo/shell/plugins/<id>/ and fills in the `plugins`
// line below with each manifest's id, kinds, prefix, keepLoaded, replaces, barWidget
// block and entry-point URLs; the rest of this file ships unchanged. Nothing
// else is discovered at runtime, with one opt-in exception: when
// marchyo.shell.devPlugins.enable baked `Config.devPlugins`, the entries
// `marchyo plugin dev` wrote to dev-plugins/index.json under the shell state
// dir join the index (kinds that run at startup are refused, see
// PluginManifest.js). Changing that index needs a shell reload.
//
// The checked-in dev default is empty, so a `quickshell -p shell` dev run and
// any host with no declared plugins load no plugin. One consumer per kind:
//   bar-widget  shell.qml componentFor() -> barWidgetComponent(id)
//   launcher    Launcher/LauncherWindow -> launcherComponents(), and
//               Services/Launcher routes on launcherPrefixes()
//   daemon      shell.qml -> daemonComponents(), one instance each at the root
//   panel, menu, overlay, service
//               Plugins/PluginLayer -> Services/PluginHost (allPlugins())
//   bar         shell.qml -> barComponent(Config.barPlugin)
QtObject {
    id: root

    // Each entry: { id, name, version, kinds: [..], prefix, keepLoaded,
    // replaces: [native role], barWidget, entryPoints: { key: url } }
    // package.nix replaces this exact line, so keep it on one line.
    readonly property var plugins: []

    readonly property string devDir: Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/shell/dev-plugins"

    // The validated dev entries; empty unless the host enabled the loader.
    readonly property var _dev: {
        if (!Config.devPlugins)
            return {
                "entries": [],
                "refused": []
            };
        const baked = [];
        for (let i = 0; i < root.plugins.length; i++)
            baked.push(root.plugins[i].id);
        return PM.devEntries(devFile.text(), root.devDir, baked);
    }
    readonly property var all: root.plugins.concat(root._dev.entries)

    // Logged once per load so a refused or mounted dev plugin is never silent.
    Component.onCompleted: {
        if (!Config.devPlugins)
            return;
        for (let i = 0; i < root._dev.entries.length; i++)
            console.warn(`dev plugin ${root._dev.entries[i].id}: unreviewed code from ${root.devDir}, running unsandboxed`);
        for (let j = 0; j < root._dev.refused.length; j++)
            console.warn(`dev plugin ${root._dev.refused[j].id} refused: ${root._dev.refused[j].reason}`);
    }

    readonly property var devFile: FileView {
        id: devFile
        path: Config.devPlugins ? root.devDir + "/index.json" : ""
        blockLoading: true
        printErrors: false
    }

    // Every plugin entry: baked ones, then the dev ones (marked `dev`).
    function allPlugins(): var {
        return root.all;
    }

    // Id of the plugin that replaces native role `role` (for example
    // "panel.audio" or "polkit"), or "" while the native component owns it.
    function replacementFor(role: string): string {
        return PM.replacementFor(root.all, role);
    }

    function pluginById(id: string): var {
        for (let i = 0; i < root.all.length; i++)
            if (root.all[i].id === id)
                return root.all[i];
        return null;
    }

    // Component for a plugin bar-widget id, or null if no plugin claims it.
    // createComponent on an absolute file URL keeps this synchronous at first
    // use and cached thereafter.
    property var _cache: ({})
    function _componentFor(id: string, key: string): Component {
        const p = root.pluginById(id);
        if (p === null || !p.entryPoints || !p.entryPoints[key])
            return null;
        const ck = id + "/" + key;
        if (!root._cache[ck])
            root._cache[ck] = Qt.createComponent(p.entryPoints[key]);
        return root._cache[ck];
    }

    function barWidgetComponent(id: string): Component {
        return root._componentFor(id, "barWidget");
    }

    // Component of a `bar` plugin id (marchyo.shell.barPlugin), or null.
    function barComponent(id: string): Component {
        return root._componentFor(id, "bar");
    }

    // Plugins carrying entry point `key`, each with its Component. `all`
    // changes only on a shell reload, so the bindings below evaluate once and
    // act as the cache.
    function _withEntry(key: string): var {
        const out = [];
        for (let i = 0; i < root.all.length; i++) {
            const p = root.all[i];
            if (p.entryPoints && p.entryPoints[key])
                out.push({
                    "id": p.id,
                    "prefix": p.prefix || "",
                    "component": Qt.createComponent(p.entryPoints[key])
                });
        }
        return out;
    }
    readonly property var _launchers: root._withEntry("launcher")
    readonly property var _daemons: root._withEntry("daemon")
    readonly property var _prefixes: {
        const out = {};
        for (let i = 0; i < root.all.length; i++) {
            const p = root.all[i];
            if (p.entryPoints && p.entryPoints.launcher && p.prefix)
                out[p.prefix] = p.id;
        }
        return out;
    }

    // [{ id, prefix, component }] for every launcher plugin. The component's
    // root is a qs.Launcher Provider.
    function launcherComponents(): var {
        return root._launchers;
    }

    // { prefix: plugin id } for Commons/LauncherProviders.js route(). Builds
    // no components, so routing never loads plugin QML.
    function launcherPrefixes(): var {
        return root._prefixes;
    }

    // [{ id, prefix, component }] for every daemon plugin. The
    // component's root is a non-visual Item or QtObject.
    function daemonComponents(): var {
        return root._daemons;
    }
}
