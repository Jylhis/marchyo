pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Runtime theme state: the one colors.json read for the whole seat.
//
// modules/home/theme-runtime.nix materializes a colors.json (name, variant,
// palette) in every theme dir behind the ~/.config/marchyo/current-theme
// pointer; `marchyo theme set/next` repoints it. Commons/Color.qml
// delegates its tokens here (the bar live-recolors, matching waybar's
// runtime-switch behavior) and Bar/ThemeWidget shows/cycles the theme.
//
// Dev defaults: the embedded fallback palette is the Jylhis Field (dark)
// variant so `quickshell -p shell` runs standalone; the Nix build
// (packages/marchyo-shell/package.nix) regenerates this file with the host's
// build-time variant hex-swapped into the fallback block.
//
// Lives in Commons/ (not Services/) on purpose: the generated Color.qml
// references it, and Commons referencing Services would close a module
// import cycle (Services singletons import qs.Commons).
QtObject {
    id: root

    property string name: ""
    property string variant: ""

    // Whole-object reassignment only: bindings read Theme.palette.<token>,
    // and var properties notify per value, not per member.
    property var palette: ({
            bg: "#0d0f14",
            bgSubtle: "#14171e",
            surface: "#1b1f28",
            surfaceRaised: "#232833",
            text: "#d6dae2",
            textMuted: "#9aa0ab",
            textHeading: "#f2f4f8",
            textFaint: "#656b76",
            accent: "#e0a33a",
            accentHover: "#f0b95c",
            accentSubtle: "#262119",
            brand: "#ef8a4a",
            contour: "#6f9be0",
            border: "#2b303b",
            borderStrong: "#3a4150",
            decorator: "#39415a",
            selectionBg: "#3a2f1c",
            cursor: "#e0a33a",
            scrim: "#05060a",
            statusErr: "#f0685f",
            statusWarn: "#d9b34a",
            statusOk: "#6bbf6b",
            statusInfo: "#5fb8cf"
        })

    // No reading (no marchyo desktop / theme manifest): widgets stay hidden.
    readonly property bool known: variant !== ""

    function themePath(): string {
        const config = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const base = config && config !== "" ? config : (home ?? "") + "/.config";
        return base + "/marchyo/current-theme/colors.json";
    }

    function apply(text: string): void {
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            return; // missing/unreadable file: keep the last good state
        }
        if (obj === null || typeof obj !== "object")
            return;
        if (typeof obj.name === "string")
            root.name = obj.name;
        if (obj.variant === "dark" || obj.variant === "light")
            root.variant = obj.variant;
        if (obj.colors !== undefined && typeof obj.colors === "object")
            root.palette = obj.colors;
    }

    function toggle(): void {
        toggleProc.running = true;
    }

    readonly property var fileView: FileView {
        id: fileView
        path: root.themePath()
        watchChanges: true
        onLoaded: root.apply(fileView.text())
        onFileChanged: fileView.reload()
    }

    // Click toggle -> CLI swap -> immediate re-read (the CLI has repointed
    // the pointer before it exits, so the reload sees the new theme).
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "theme", "next"]
        onExited: code => fileView.reload()
    }

    // The CLI swaps the pointer atomically (symlink to a temp name, rename
    // over it), which replaces the watched inode — inotify on the old file
    // never fires. One cheap 5s poll covers switches from the keybind or
    // another terminal; own toggles re-read immediately via onExited above.
    readonly property var poll: Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            fileView.reload();
            root.apply(fileView.text());
        }
    }

    // Blocking initial read before the first frame: no flash of fallback
    // colors at startup.
    Component.onCompleted: root.apply(fileView.text())
}
