// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Commons` import is rewritten to `qs.compat.Commons`; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick
import qs.compat.Commons

// Base item every bar widget extends. The host injects `bar` (host Bar
// instance), `moduleName` (canonical id the host registry uses for settings
// lookup and inline IPC routing), and `settings` (per-widget shell.json
// overrides).
Item {
    id: root

    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})

    // Bar geometry lifted off the host, so the `bar ? bar.x : fallback` ternary
    // stays out of every widget body.
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

    // Run `method` on every live instance of this widget. An IPC target only
    // ever routes to one handler, but a bar surface exists per monitor, so the
    // instance that owns the target relays the call to its peers, otherwise a
    // refresh would land on a single screen and leave the others stale.
    function broadcast(method) {
        var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root];
        for (var i = 0; i < items.length; i++) {
            if (items[i] && typeof items[i][method] === "function")
                items[i][method]();
        }
    }

    // Read a single value from this widget's inline shell.json entry, with a
    // fallback for missing/null values.
    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }
}
