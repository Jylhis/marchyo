pragma Singleton
import QtQuick

// Tracks which summonable panel is currently open, and on which output. Panels
// are mutually exclusive — opening one closes any other — so the shell shows at
// most one at a time. This is the whole "panel registry": a shared string, in
// process. Bar widgets call toggle(id, item) on click; each Ui/Panel binds its
// visibility to openId === id and its screen to screenName. No manifest system,
// no plugin discovery (see plans/shell.md).
QtObject {
    id: root

    // Empty string = nothing open; otherwise the panelId of the open panel.
    property string openId: ""

    // Name of the output the panel should appear on: the screen whose bar was
    // clicked, or the focused output for an IPC summon. Panels are instantiated
    // once, outside shell.qml's per-screen Variants loop, so without this they
    // always opened on the default output no matter which monitor's bar was
    // clicked — dismiss area included.
    property string screenName: ""

    function toggle(id, item) {
        if (root.openId === id) {
            root.close();
            return;
        }
        root.open(id, item);
    }

    function open(id, item) {
        // An IPC summon (the Hyprland binds) passes no item, so fall back to the
        // focused output rather than to whichever screen is Quickshell's
        // default.
        const name = Screens.nameOf(item);
        root.screenName = name.length > 0 ? name : Screens.focusedName;
        root.openId = id;
    }

    function close() {
        root.openId = "";
        root.screenName = "";
    }
}
