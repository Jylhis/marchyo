pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "../Commons/DevTools.js" as Tools

// Dev sandbox hooks. Inert unless the environment opts in:
// MARCHYO_SHELL_OUTPUT pins summoned surfaces to one output (Services/Screens),
// MARCHYO_SHELL_NO_MOTION=1 zeroes every duration (Services/Motion), and
// MARCHYO_SHELL_DEV=1 enables the "dev" IPC target below. Surfaces register
// their window and visible card with register(); the target reports and
// grabs them. A singleton, so seat-global like PanelManager.
QtObject {
    id: root

    readonly property string outputOverride: Quickshell.env("MARCHYO_SHELL_OUTPUT") || ""
    readonly property bool noMotion: Tools.flagOn(Quickshell.env("MARCHYO_SHELL_NO_MOTION"))
    readonly property bool enabled: Tools.flagOn(Quickshell.env("MARCHYO_SHELL_DEV"))

    // IPC replies; dev tooling output, not user text.
    readonly property var replies: ({
            "closed": "closed",
            "noSurface": "no visible surface"
        })

    // Set by LauncherWindow: the setQuery()/select() entry points.
    property var launcher: null

    // "none", "pending", "ok" or an error: the outcome of the last grab().
    property string grabResult: "none"

    // name -> {window, card}; plain data, not bound.
    property var _entries: ({})

    // Settle tracking: a state change clears `quiet` until the longest
    // transition has run out, and `framesSince` counts frames rendered after it.
    property bool quiet: true
    property int framesSince: 99
    readonly property int minFrames: 2

    function start(): void {
        if (root.enabled)
            root.bump();
    }

    function register(name: string, window, card): void {
        if (!root.enabled)
            return;
        root._entries[name] = {
            "window": window,
            "card": card
        };
        window.visibleChanged.connect(root.bump);
    }

    // Also refreshes the monitors' reserved areas, which surfaces() reads.
    function bump(): void {
        Hyprland.refreshMonitors();
        root.quiet = false;
        root.framesSince = 0;
        quietTimer.restart();
    }

    readonly property var quietTimer: Timer {
        interval: Style.duration(Style.motionLong) + 50
        onTriggered: root.quiet = true
    }

    readonly property var frames: FrameAnimation {
        running: root.enabled && root.framesSince < root.minFrames
        onTriggered: root.framesSince++
    }

    readonly property var launcherWatch: Connections {
        target: Launcher
        enabled: root.enabled
        function onModeChanged() {
            root.bump();
        }
        function onQueryChanged() {
            root.bump();
        }
    }

    readonly property var panelWatch: Connections {
        target: PanelManager
        enabled: root.enabled
        function onOpenIdChanged() {
            root.bump();
        }
    }

    readonly property var overviewWatch: Connections {
        target: Overview
        enabled: root.enabled
        function onOpenChanged() {
            root.bump();
        }
    }

    function _live(entry): bool {
        const w = entry.window;
        const c = entry.card;
        return !!w && !!c && w.visible && !!w.screen && c.width > 0 && c.height > 0;
    }

    function _geometry(entry): var {
        const w = entry.window;
        const offset = entry.card.mapToItem(w.contentItem, 0, 0);
        const ignores = w.exclusionMode === ExclusionMode.Ignore;
        const monitor = Hyprland.monitorFor(w.screen);
        const reserved = ignores || !monitor ? null : (monitor.lastIpcObject || {}).reserved;
        return {
            "output": w.screen.name,
            "origin": Tools.windowOrigin(w.anchors, w.margins, w, w.screen, reserved),
            "offset": {
                "x": offset.x,
                "y": offset.y
            },
            "width": entry.card.width,
            "height": entry.card.height
        };
    }

    function surfaces(): string {
        const live = {};
        for (const name of Object.keys(root._entries))
            if (root._live(root._entries[name]))
                live[name] = root._geometry(root._entries[name]);
        return JSON.stringify(Tools.describe(live));
    }

    function grab(name: string, path: string): string {
        const entry = root._entries[name];
        if (!entry || !root._live(entry))
            return root.replies.noSurface + " " + name;
        root.grabResult = "pending";
        const started = entry.card.grabToImage(result => {
            root.grabResult = result.saveToFile(path) ? "ok" : "save failed";
        });
        if (!started)
            root.grabResult = "grab failed";
        return root.grabResult;
    }

    function settled(): string {
        const idle = PanelManager.reminderPanel.status !== Loader.Loading;
        return Tools.isSettled(root.quiet && idle, root.framesSince, root.minFrames) ? "yes" : "no";
    }

    function setLauncherQuery(q: string): string {
        if (!Launcher.open || !root.launcher)
            return root.replies.closed;
        root.launcher.setQuery(q);
        root.bump();
        return "on";
    }

    function launcherSelect(index: string): string {
        if (!Launcher.open || !root.launcher)
            return root.replies.closed;
        const selected = root.launcher.select(parseInt(index));
        root.bump();
        return String(selected);
    }

    readonly property var ipc: IpcHandler {
        target: "dev"
        enabled: root.enabled

        function setLauncherQuery(q: string): string {
            return root.setLauncherQuery(q);
        }

        function launcherSelect(index: string): string {
            return root.launcherSelect(index);
        }

        function surfaces(): string {
            return root.surfaces();
        }

        function grab(name: string, path: string): string {
            return root.grab(name, path);
        }

        function grabResult(): string {
            return root.grabResult;
        }

        function settled(): string {
            return root.settled();
        }
    }
}
