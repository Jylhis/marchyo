pragma Singleton
import QtQuick

// Tracks which summonable panel is open, and on which output. Panels are
// mutually exclusive (opening one closes any other). Bar widgets call
// toggle(id, item); each Ui/Panel binds its visibility to openId === id and its
// screen to screenName. No manifest, no plugin discovery (see shell/README.md).
QtObject {
    id: root

    // Empty string = nothing open; otherwise the panelId of the open panel.
    property string openId: ""

    // Output the panel appears on: the clicked bar's screen, or the focused
    // output for an IPC summon. Panels are instantiated once (outside shell.qml's
    // per-screen Variants loop), so without this they always open on the default
    // output regardless of which monitor's bar was clicked.
    property string screenName: ""

    // Panel to return to from a detail page: set by openDetail() (the Control
    // Center opening one of the existing panels), cleared by any plain open or
    // close. Ui/Panel shows a back button while it is set.
    property string returnId: ""

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
        root.returnId = "";
        root.openId = id;
    }

    // Swap the open panel for `id` on the same output, remembering `fromId` so
    // the detail page can go back to it.
    function openDetail(id, fromId) {
        root.returnId = fromId;
        root.openId = id;
    }

    function back() {
        const target = root.returnId;
        root.returnId = "";
        root.openId = target;
    }

    function close() {
        root.openId = "";
        root.screenName = "";
        root.returnId = "";
    }
}
