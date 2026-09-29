pragma Singleton
import QtQuick

// Tracks which summonable panel is open, and on which output. Panels are
// mutually exclusive (opening one closes any other). Bar widgets call
// toggle(id, item); each Ui/Panel binds its visibility to openId === id and its
// screen to screenName. No manifest, no plugin discovery (see plans/shell.md).
QtObject {
    id: root

    // Empty string = nothing open; otherwise the panelId of the open panel.
    property string openId: ""

    // Output the panel appears on: the clicked bar's screen, or the focused
    // output for an IPC summon. Panels are instantiated once (outside shell.qml's
    // per-screen Variants loop), so without this they always open on the default
    // output regardless of which monitor's bar was clicked.
    property string screenName: ""

    function toggle(id, item) {
        if (root.openId === id) {
            root.close();
            return;
        }
        root.open(id, item);
    }

    function open(id, item) {
        // An IPC summon passes no item, so fall back to the focused output.
        const name = Screens.nameOf(item);
        root.screenName = name.length > 0 ? name : Screens.focusedName;
        root.openId = id;
    }

    function close() {
        root.openId = "";
        root.screenName = "";
    }
}
