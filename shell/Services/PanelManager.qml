pragma Singleton
import QtQuick
import qs.Commons
import "../Commons/PluginManifest.js" as PM

// Tracks which summonable panel is open, and on which output. Panels are
// mutually exclusive (opening one closes any other). Bar widgets call
// toggle(id, item); each Ui/Panel binds its visibility to openId === id and its
// screen to screenName. No manifest, no plugin discovery (see shell/README.md).
// A plugin that declares `replaces: ["panel.<id>"]` takes over that panel: the
// openers below hand the request to PluginHost and the native panel never opens.
QtObject {
    id: root

    readonly property var reminderPanel: Loader {
        active: root.openId === "reminders"
        source: "../Panels/ReminderFlow.qml"
    }

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

    // True when the panel was summoned by a key or IPC (no bar item clicked):
    // Ui/Panel then takes on-demand keyboard focus.
    property bool keyboard: false

    // Id of the plugin that replaces native panel `id`, or "".
    function replacementFor(id: string): string {
        return PluginIndex.replacementFor("panel." + id);
    }

    // The output of the clicked bar item, or the focused output when an IPC
    // summon passes no item. MARCHYO_SHELL_OUTPUT overrides both.
    function _outputOf(item): string {
        const name = Screens.pin(Screens.nameOf(item));
        return name.length > 0 ? name : Screens.focusedName;
    }

    function _summonReplacement(pluginId: string, screenName: string): void {
        root._closeNative();
        root._closeReplacements(pluginId);
        PluginHost.summonOn(pluginId, "{}", screenName);
    }

    function _closeReplacements(keepId: string): void {
        const ids = PM.panelReplacers(PluginIndex.allPlugins(), keepId);
        for (let i = 0; i < ids.length; i++)
            if (PluginHost.isOpen(ids[i]))
                PluginHost.hide(ids[i]);
    }

    function toggle(id, item) {
        const replacement = root.replacementFor(id);
        if (replacement !== "") {
            if (PluginHost.isOpen(replacement))
                PluginHost.hide(replacement);
            else
                root._summonReplacement(replacement, root._outputOf(item));
            return;
        }
        if (root.openId === id) {
            root.close();
            return;
        }
        root.open(id, item);
    }

    function open(id, item) {
        const replacement = root.replacementFor(id);
        if (replacement !== "") {
            root._summonReplacement(replacement, root._outputOf(item));
            return;
        }
        root._closeReplacements("");
        root.screenName = root._outputOf(item);
        root.returnId = "";
        root.keyboard = item ? (root.openId !== "" && root.keyboard) : true;
        root.openId = id;
    }

    // Swap the open panel for `id` on the same output, remembering `fromId` so
    // the detail page can go back to it.
    function openDetail(id, fromId) {
        const replacement = root.replacementFor(id);
        if (replacement !== "") {
            root._summonReplacement(replacement, root.screenName !== "" ? root.screenName : Screens.focusedName);
            return;
        }
        root._closeReplacements("");
        root.returnId = fromId;
        root.openId = id;
    }

    function back() {
        const target = root.returnId;
        root.returnId = "";
        root.openId = target;
    }

    function _closeNative() {
        root.openId = "";
        root.screenName = "";
        root.returnId = "";
    }

    // Closes the native panel and any plugin that replaces a native panel.
    function close() {
        root._closeNative();
        root._closeReplacements("");
    }
}
