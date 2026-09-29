pragma Singleton
import QtQuick

// Seat-global popout coordinator for omarchy-compat plugin bar widgets: at most
// one plugin popout open at a time, mirroring PanelManager's single-open model
// for compat KeyboardPanels. Each widget's PluginBarApi facade delegates its
// shared popout state and click-target registry here.
QtObject {
    id: root

    // The currently-open popout's coordinator key (its owner Panel/widget), or
    // null. KeyboardPanel reads bar.activePopout to detect a sibling popout.
    property var activePopout: null

    // Bar buttons registered for click-through while a popout is open, so the
    // popout's full-screen dismiss overlay can forward a click on another bar
    // icon to that icon (switching popouts in one click).
    property var clickTargets: []

    function requestPopout(owner) {
        if (root.activePopout && root.activePopout !== owner && root.activePopout.closeForPopoutSwitch)
            root.activePopout.closeForPopoutSwitch();
        root.activePopout = owner;
    }

    function releasePopout(owner) {
        if (root.activePopout === owner)
            root.activePopout = null;
    }

    function registerClickTarget(target) {
        if (root.clickTargets.indexOf(target) === -1) {
            const next = root.clickTargets.slice();
            next.push(target);
            root.clickTargets = next;
        }
    }

    function unregisterClickTarget(target) {
        const i = root.clickTargets.indexOf(target);
        if (i !== -1) {
            const next = root.clickTargets.slice();
            next.splice(i, 1);
            root.clickTargets = next;
        }
    }

    // Adjacent-popout switching (Tab at a panel edge) is not wired for compat
    // widgets yet; report "not handled" so the plugin keeps focus.
    function switchPanelFrom(owner, direction) {
        return false;
    }

    function targetBelongsToWindow(target, window) {
        return !!(target && target.QsWindow && target.QsWindow.window === window);
    }

    // Per-monitor broadcast (BarWidget.broadcast) is unused by the imported
    // plugins; return an empty list so any stray call is a harmless no-op.
    function moduleWidgets(id) {
        return [];
    }
}
