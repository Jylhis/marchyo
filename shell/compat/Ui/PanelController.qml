// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Commons` import is rewritten to `qs.compat.Commons`; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick

// Stores the open state for a shell panel. Panel owns the public lifecycle
// methods and IPC wiring; this object only keeps state separate from the
// panel implementation's own properties.
QtObject {
    id: root

    property bool open: false

    function toggle() {
        open = !open;
    }
    function show() {
        if (!open)
            open = true;
    }
    function hide() {
        open = false;
    }
}
