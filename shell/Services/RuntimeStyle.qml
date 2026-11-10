pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Appearance.js" as Appearance
import "../Commons/Paths.js" as Paths

// Runtime style overrides: $XDG_STATE_HOME/marchyo/shell/style.json, written by
// the CLI (`marchyo toggle reduce-motion`, `marchyo font set --kind ui`,
// `marchyo theme bar-position`, `marchyo theme bar-background`) and watched
// here. Every key is optional; an absent key restores the baked default. The
// values land in Commons/Style, which the rest of the shell binds to. One file
// for every surface, so a singleton; start() is called once from shell.qml.
QtObject {
    id: root

    readonly property string dir: Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/shell"
    readonly property string path: root.dir + "/style.json"

    property bool reduceMotion: false
    property string uiFont: ""
    property string barPosition: ""
    property string barBackground: ""

    // MARCHYO_SHELL_NO_MOTION forces motion off for deterministic dev shots.
    function syncMotion(): void {
        Style.motionRuntimeOff = root.reduceMotion || Dev.noMotion;
    }

    onReduceMotionChanged: root.syncMotion()
    onUiFontChanged: Style.uiFont = root.uiFont
    onBarPositionChanged: Style.barPosition = root.barPosition === "" ? "top" : root.barPosition
    onBarBackgroundChanged: Style.barBackground = root.barBackground

    function apply(text: string): void {
        const s = Appearance.parseStyle(text.length <= Appearance.MAX_CHARS ? text : "");
        root.reduceMotion = s.reduceMotion;
        root.uiFont = s.uiFont;
        root.barPosition = s.barPosition;
        root.barBackground = s.barBackground;
        root.syncMotion();
    }

    // The watcher needs the directory; create it so the first CLI write is seen.
    function start(): void {
        mkdirProc.running = true;
    }

    readonly property var mkdirProc: Process {
        command: [Config.mkdir, "-p", root.dir]
        onExited: root.file.reload()
    }

    readonly property var file: FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.apply("")
    }
}
