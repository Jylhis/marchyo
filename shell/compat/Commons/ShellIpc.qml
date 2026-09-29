// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Commons` import is rewritten to `qs.compat.Commons`; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick
import Quickshell.Io

// An IpcHandler the shell can also answer over its own socket (see
// IpcRegistry), so omarchy-shell reaches it without a qs ipc client. qs ipc
// still reaches it as before.
IpcHandler {
    id: handler

    Component.onCompleted: IpcRegistry.register(handler)
    Component.onDestruction: IpcRegistry.unregister(handler)
}
