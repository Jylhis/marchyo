pragma Singleton
import QtQuick

// omarchy-compat `Util` singleton. The imported omarchy plugins only use
// `alpha(color, a)` (translucent tints for panel fills), so that is all the
// shim provides.
QtObject {
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
