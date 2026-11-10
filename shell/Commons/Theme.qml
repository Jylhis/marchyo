pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Paths.js" as Paths

// Runtime theme state: the one colors.json read for the whole seat.
//
// modules/home/theme-runtime.nix materializes a colors.json (name, variant,
// palette) in every theme dir behind the ~/.config/marchyo/current-theme
// pointer; `marchyo theme set/next` repoints it. Commons/Colors.qml
// delegates its tokens here (the bar live-recolors, matching waybar's
// runtime-switch behavior) and Bar/ThemeWidget shows/cycles the theme.
//
// Dev defaults: the embedded fallback palette is the Jylhis Dark
// variant so `quickshell -p shell` runs standalone; the Nix build
// (packages/marchyo-shell/package.nix) regenerates this file with the host's
// build-time variant hex-swapped into the fallback block.
//
// Lives in Commons/ (not Services/) on purpose: the generated Colors.qml
// references it, and Commons referencing Services would close a module
// import cycle (Services singletons import qs.Commons).
QtObject {
    id: root

    property string name: ""
    property string variant: ""

    // Whole-object reassignment only: bindings read Theme.palette.<token>,
    // and var properties notify per value, not per member.
    property var palette: ({
            bg: "#0c0f14",
            bgSubtle: "#14171c",
            surface: "#1c1f24",
            surfaceRaised: "#262a2f",
            text: "#d1d4dc",
            textMuted: "#878b91",
            textHeading: "#e7ebf2",
            textFaint: "#5d6067",
            accent: "#f5a351",
            focusRing: "#f5a351",
            accentHover: "#ffb063",
            accentSubtle: "#281604",
            brand: "#f8763a",
            contour: "#7ca2ff",
            border: "#242c37",
            borderStrong: "#3f4754",
            decorator: "#525a6b",
            selectionBg: "#3c2206",
            cursor: "#f5a351",
            scrim: "#040508",
            destructive: "#ffb2b4",
            statusErr: "#ff8271",
            statusWarn: "#ec871d",
            statusOk: "#39ae34",
            statusInfo: "#17a4ed"
        })

    // No reading (no marchyo desktop / theme manifest): widgets stay hidden.
    readonly property bool known: variant !== ""

    function themePath(): string {
        return Paths.xdgDir(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"), "/.config") + "/marchyo/current-theme/colors.json";
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
        root.toggleProc.running = true;
    }

    readonly property var fileView: FileView {
        path: root.themePath()
        // Makes the text() read in Component.onCompleted below actually
        // block; without it the first read returns "" and the fallback paints
        // the first frame.
        blockLoading: true
        watchChanges: true
        // A missing colors.json is an expected state (no marchyo desktop /
        // pre-Milestone-1 pointer): stay quiet, apply() keeps the fallback.
        printErrors: false
        onLoaded: root.apply(root.fileView.text())
        onFileChanged: root.fileView.reload()
    }

    // Click toggle -> CLI swap -> immediate re-read (the CLI has repointed
    // the pointer before it exits, so the reload sees the new theme).
    readonly property var toggleProc: Process {
        command: [Config.marchyo, "theme", "next"]
        onExited: code => root.fileView.reload()
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
            root.fileView.reload();
            root.apply(root.fileView.text());
        }
    }

    // Blocking initial read before the first frame: no flash of fallback
    // colors at startup.
    Component.onCompleted: root.apply(root.fileView.text())
}
