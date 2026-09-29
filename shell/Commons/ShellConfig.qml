pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Runtime shell configuration: the one shell.json read for the whole seat.
//
// modules/home/marchyo-shell.nix materializes ~/.config/marchyo/shell.json from
// the marchyo.shell.* options (generated, read-only — the build-time Option A
// model: reproducible, but read live so a rebuild's new layout applies without
// restarting the shell). Same read pattern as Commons/Theme.qml: a watched
// FileView plus a 5s poll (an atomic symlink swap replaces the inode, so
// inotify on the old file never fires).
//
// The default bar layout below reproduces the static widget order the shell
// shipped before it became config-driven, so a host with no shell.json — or an
// empty one — looks identical. shell.qml resolves each entry's `id` to a
// widget Component (first-party) or a plugin bar-widget (Commons/PluginIndex).
//
// Lives in Commons/ (not Services/) for the same reason as Theme.qml: it is a
// leaf the rest of the tree reads, and Commons must not import Services.
QtObject {
    id: root

    // Default bar layout. Ids are resolved by shell.qml's barComponents map
    // (and, for plugins, Commons/PluginIndex).
    readonly property var defaultBar: ({
            left: [
                {
                    id: "marchyo.session"
                },
                {
                    id: "marchyo.workspaces"
                },
                {
                    id: "marchyo.activeWindow"
                }
            ],
            center: [
                {
                    id: "marchyo.clock"
                }
            ],
            right: [
                {
                    id: "marchyo.screenRecording"
                },
                {
                    id: "marchyo.reminders"
                },
                {
                    id: "marchyo.tray"
                },
                {
                    id: "marchyo.media"
                },
                {
                    id: "marchyo.dictation"
                },
                {
                    id: "marchyo.caffeine"
                },
                {
                    id: "marchyo.theme"
                },
                {
                    id: "marchyo.dnd"
                },
                {
                    id: "marchyo.keyboardLayout"
                },
                {
                    id: "marchyo.bluetooth"
                },
                {
                    id: "marchyo.network"
                },
                {
                    id: "marchyo.mic"
                },
                {
                    id: "marchyo.audio"
                },
                {
                    id: "marchyo.cpu"
                },
                {
                    id: "marchyo.powerProfile"
                },
                {
                    id: "marchyo.peripherals"
                },
                {
                    id: "marchyo.battery"
                }
            ]
        })

    // Parsed shell.json (empty object until first read).
    property var config: ({})

    // Per-plugin runtime settings overlay, keyed by plugin id, written by the
    // omarchy-bar compat shim (packages/marchyo-shell/package.nix) into
    // $XDG_STATE_HOME/marchyo/shell/plugin-settings.json. Kept separate from the
    // generated (read-only) shell.json: shell.qml's applyWidget merges
    // pluginSettings[id] over a plugin widget's inline settings at load, so an
    // omarchy plugin that persists a setting from its popup keeps it across
    // shell restarts. Merged at load (not live) to avoid rebuilding the bar.
    property var pluginSettings: ({})

    // Effective bar layout: the file's bar.layout when present, else the
    // default. Each section falls back independently so a partial override is
    // still valid.
    readonly property var bar: {
        const b = root.config && root.config.bar ? root.config.bar : null;
        const layout = b && b.layout ? b.layout : root.defaultBar;
        return {
            left: layout.left || root.defaultBar.left,
            center: layout.center || root.defaultBar.center,
            right: layout.right || root.defaultBar.right
        };
    }

    // Idle thresholds (seconds); consumed by a future in-shell idle service.
    readonly property int idleScreensaver: root.config.idle && root.config.idle.screensaver ? root.config.idle.screensaver : 150
    readonly property int idleLock: root.config.idle && root.config.idle.lock ? root.config.idle.lock : 300

    function configPath(): string {
        const config = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const base = config && config !== "" ? config : (home ?? "") + "/.config";
        return base + "/marchyo/shell.json";
    }

    function pluginSettingsPath(): string {
        const state = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME");
        const base = state && state !== "" ? state : (home ?? "") + "/.local/state";
        return base + "/marchyo/shell/plugin-settings.json";
    }

    function applyPluginSettings(text: string): void {
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            return; // missing/unreadable: keep the last good overlay (or {})
        }
        if (obj === null || typeof obj !== "object")
            return;
        root.pluginSettings = obj;
    }

    function apply(text: string): void {
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            return; // missing/unreadable: keep the last good config (or {})
        }
        if (obj === null || typeof obj !== "object")
            return;
        root.config = obj;
    }

    readonly property var fileView: FileView {
        id: fileView
        path: root.configPath()
        watchChanges: true
        printErrors: false
        onLoaded: root.apply(fileView.text())
        onFileChanged: fileView.reload()
    }

    // Plugin settings overlay reader. Watched so a save takes effect for the
    // next widget load; no poll (writes are rare, and unlike shell.json it is
    // updated in place by omarchy-bar, so inotify fires).
    readonly property var pluginSettingsView: FileView {
        id: pluginSettingsView
        path: root.pluginSettingsPath()
        watchChanges: true
        printErrors: false
        onLoaded: root.applyPluginSettings(pluginSettingsView.text())
        onFileChanged: pluginSettingsView.reload()
    }

    // The generator writes shell.json via an atomic replace, so the watched
    // inode changes and inotify misses it — one cheap 5s poll covers that,
    // exactly as Commons/Theme.qml does for colors.json.
    readonly property var poll: Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            fileView.reload();
            root.apply(fileView.text());
        }
    }

    // Blocking initial read before the first frame: no flash of the default
    // layout when a custom one exists. Also seed the plugin settings overlay.
    Component.onCompleted: {
        root.apply(fileView.text());
        root.applyPluginSettings(pluginSettingsView.text());
    }
}
