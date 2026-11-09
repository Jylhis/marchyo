pragma Singleton
import QtQuick

// Index of the shell plugins baked into this store shell (the build-time
// Option A model). packages/marchyo-shell/package.nix copies each declared
// plugin into share/marchyo/shell/plugins/<id>/ and fills in the `plugins`
// line below with each manifest's id, kinds, prefix, and entry-point URLs;
// the rest of this file ships unchanged. Nothing is discovered at runtime;
// there is no ~/.config plugin dir and no hot-reload.
//
// The checked-in dev default is empty, so a `quickshell -p shell` dev run and
// any host with no declared plugins load no plugin. One consumer per kind:
//   bar-widget  shell.qml componentFor() -> barWidgetComponent(id)
//   launcher    Launcher/LauncherWindow -> launcherComponents(), and
//               Services/Launcher routes on launcherPrefixes()
//   daemon      shell.qml -> daemonComponents(), one instance each at the root
QtObject {
    id: root

    // Each entry: { id, name, version, kinds: [..], prefix, entryPoints: { key: url } }
    // package.nix replaces this exact line, so keep it on one line.
    readonly property var plugins: []

    // Component for a plugin bar-widget id, or null if no plugin claims it.
    // createComponent on an absolute file URL keeps this synchronous at first
    // use and cached thereafter.
    property var _cache: ({})
    function barWidgetComponent(id: string): Component {
        for (let i = 0; i < root.plugins.length; i++) {
            const p = root.plugins[i];
            if (p.id === id && p.entryPoints && p.entryPoints.barWidget) {
                if (!root._cache[id])
                    root._cache[id] = Qt.createComponent(p.entryPoints.barWidget);
                return root._cache[id];
            }
        }
        return null;
    }

    // Plugins carrying entry point `key`, each with its Component. `plugins`
    // never changes, so the bindings below evaluate once and act as the cache.
    function _withEntry(key: string): var {
        const out = [];
        for (let i = 0; i < root.plugins.length; i++) {
            const p = root.plugins[i];
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
        for (let i = 0; i < root.plugins.length; i++) {
            const p = root.plugins[i];
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
