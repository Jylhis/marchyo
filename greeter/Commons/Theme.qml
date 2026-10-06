pragma Singleton
import QtQuick
import Quickshell.Io

// Greeter theme: the Jylhis Dark fallback palette, variant-swapped at build
// time by packages/marchyo-shell/package.nix (same generator as the shell's
// Theme.qml), with a runtime override from the session theme marker.
//
// `marchyo theme set` writes the active theme's colors.json to
// /var/lib/marchyo/greeter/theme.json (a root:users 1775 dir, see
// modules/nixos/boot.nix). That file is user-writable, so the greeter never
// points a FileView at it: a FileView on the directory (preload: false, never
// read) is the doorbell, and a bounded, time-limited `head` reads the file.
// Only #rrggbb strings for keys the baked palette already has are taken;
// anything else keeps the baked value. A missing or invalid file restores the
// baked palette.
QtObject {
    id: root

    property string name: ""
    property string variant: ""

    // Whole-object reassignment only: bindings read Theme.palette.<token>,
    // and var properties notify per value, not per member.
    property var palette: root.baked

    readonly property string markerDir: "/var/lib/marchyo/greeter"
    readonly property string markerPath: root.markerDir + "/theme.json"
    readonly property int maxChars: 16 * 1024

    // The build-time host palette every runtime value falls back to.
    readonly property var baked: ({
            bg: "#0c0f14",
            bgSubtle: "#14171c",
            surface: "#1c1f24",
            surfaceRaised: "#262a2f",
            text: "#d1d4dc",
            textMuted: "#878b91",
            textHeading: "#e7ebf2",
            textFaint: "#5d6067",
            accent: "#f5a351",
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

    // The greeter always has a known palette (the build bakes the host
    // variant); `known` mirrors the shell's Theme for API compatibility.
    readonly property bool known: true

    function reset(): void {
        root.name = "";
        root.variant = "";
        root.palette = root.baked;
    }

    function apply(text: string): void {
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            obj = null;
        }
        if (obj === null || typeof obj !== "object" || obj.colors === null || typeof obj.colors !== "object") {
            root.reset();
            return;
        }
        const hex = /^#[0-9a-fA-F]{6}$/;
        const next = {};
        for (const key in root.baked) {
            const v = obj.colors[key];
            next[key] = (typeof v === "string" && hex.test(v)) ? v : root.baked[key];
        }
        root.name = typeof obj.name === "string" && obj.name.length <= 128 ? obj.name : "";
        root.variant = obj.variant === "dark" || obj.variant === "light" ? obj.variant : "";
        root.palette = next;
    }

    function refresh(): void {
        if (readProc.running)
            readProc.pending = true;
        else
            readProc.running = true;
    }

    // Doorbell: rings on any entry change in the marker dir (the CLI's
    // temp-file + rename replace included). Never loads anything.
    readonly property var doorbell: FileView {
        path: root.markerDir
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    // `timeout` bounds a FIFO planted at the marker path; `head -c` bounds
    // the size. A missing file yields empty output, which resets.
    readonly property var readProc: Process {
        id: readProc
        property bool pending: false
        command: [Config.timeout, "2", Config.head, "-c", String(root.maxChars + 1), "--", root.markerPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > root.maxChars)
                    root.reset();
                else
                    root.apply(text);
            }
        }
        onExited: {
            if (readProc.pending) {
                readProc.pending = false;
                readProc.running = true;
            }
        }
    }

    Component.onCompleted: root.refresh()
}
