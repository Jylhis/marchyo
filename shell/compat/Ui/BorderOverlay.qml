import QtQuick

// omarchy-compat `BorderOverlay` stub. omarchy uses this to draw gradient or
// per-side borders; the shim's Border singleton always reports uniform native
// borders (needsOverlay === false), so BorderSurface never activates its
// overlay Loader. This type exists only so that inactive `sourceComponent:
// BorderOverlay { ... }` reference resolves at load time.
Item {
    property real radius: 0
    property var borderSpec: null
}
