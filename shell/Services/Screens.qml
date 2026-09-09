pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland

// Screen lookup for the seat-global windows (panels, OSD, toast stack).
//
// Those surfaces are instantiated once, outside shell.qml's per-screen Variants
// loop, so without an explicit `screen:` binding they all land on Quickshell's
// default output — a panel summoned from the second monitor's bar opened on the
// first, and its dismiss area with it. Ui/TooltipWindow already does this
// resolution inline; this singleton is the shared version for the rest.
QtObject {
    id: root

    // The QsScreen with this name, or null (which means "the default screen" to
    // a PanelWindow.screen binding).
    function byName(name) {
        if (!name || name.length === 0)
            return null;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i];
        return null;
    }

    // Name of the screen a visual item currently lives on, via the attached
    // Window.window (QScreen.name matches QsScreen.name). Defensive: an item
    // whose window cannot be resolved yields "", i.e. the default screen. Same
    // approach as Services/Tooltip.show().
    function nameOf(item) {
        if (!item)
            return "";
        try {
            const w = item.Window.window;
            return w && w.screen ? w.screen.name : "";
        } catch (e) {
            return "";
        }
    }

    // Where a surface belongs when nothing summoned it from a particular bar
    // (a notification, an OSD, an IPC-triggered panel): the output with input
    // focus.
    readonly property string focusedName: {
        const mon = Hyprland.focusedMonitor;
        return mon ? mon.name : "";
    }
    readonly property var focused: root.byName(root.focusedName)
}
