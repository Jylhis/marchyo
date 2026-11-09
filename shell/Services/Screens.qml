pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import "../Commons/DevTools.js" as Tools

// Screen lookup for the seat-global windows (panels, OSD, toast stack). Those
// surfaces are instantiated once, outside shell.qml's per-screen Variants loop,
// so without an explicit `screen:` binding they all land on the default output.
// This singleton resolves the right output for them.
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

    readonly property var names: Quickshell.screens.map(s => s.name)

    // `name`, unless MARCHYO_SHELL_OUTPUT names an existing output (the dev
    // sandbox pins every summoned surface to one output).
    function pin(name: string): string {
        return Tools.pickOutput(Dev.outputOverride, root.names, name);
    }

    // Where a surface belongs when nothing summoned it from a particular bar
    // (a notification, an OSD, an IPC-triggered panel): the output with input
    // focus.
    readonly property string focusedName: {
        const mon = Hyprland.focusedMonitor;
        return root.pin(mon ? mon.name : "");
    }
    readonly property var focused: root.byName(root.focusedName)

    // Screens backed by a real output. With no monitor connected, Qt shows a
    // nameless zero-size placeholder and Hyprland a FALLBACK output; neither
    // can carry a lock surface.
    readonly property int realCount: {
        const screens = Quickshell.screens;
        let n = 0;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (s && s.name && s.name !== "FALLBACK" && s.width > 0 && s.height > 0)
                n++;
        }
        return n;
    }
}
