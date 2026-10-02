import QtQuick
import Quickshell
import qs.Ui
import qs.Bar
import qs.Services

// Offscreen type-check harness (`just -f shell/Justfile check`): instantiates
// the Ui primitives and every Bar/ widget — the non-window components of the
// shell — inside a plain Item, with the Panels/OSD/notification surfaces
// (PanelWindows; they need a layer-shell compositor) represented only by their
// shared services. Run under QT_QPA_PLATFORM=offscreen, the process quits
// itself after a settle period; "Configuration Loaded" plus no QML
// warnings/errors from the shell's own files means the tree parses and binds
// cleanly. Service-level warnings from Quickshell itself (no Hyprland event
// socket, missing external tools) are expected offscreen and ignored.
ShellRoot {
    Item {
        id: harnessRoot
        width: 1280
        height: 64

        // Pull in the lock service singleton (PAM state machine; the
        // WlSessionLock surface itself needs a compositor, like the panels).
        readonly property var lockService: Lock

        BarItem {
            x: 0
            text: "harness"
            tooltipText: "harness tooltip"
        }
        BarSeparator {
            x: 180
        }
        // One real section driven by inline components: a visible item, a
        // hidden one (collapse binding), and separators (cluster-aware
        // visibility). Exercises Ui/BarSection's slot Loaders offscreen
        // against the same logic the live bar uses.
        readonly property var harnessResolve: ({
                "marchyo.session": cHarnessVisible,
                "marchyo.workspaces": cHarnessHidden,
                "marchyo.activeWindow": cHarnessVisible,
                "marchyo.clock": cHarnessVisible,
                "marchyo.media": cHarnessHidden,
                "marchyo.mic": cHarnessHidden,
                "marchyo.audio": cHarnessVisible,
                "marchyo.battery": cHarnessHidden
            })
        Component {
            id: cHarnessVisible
            BarItem {
                text: "harness"
            }
        }
        Component {
            id: cHarnessHidden
            BarItem {
                text: "hidden"
                visible: false
            }
        }
        BarSection {
            x: 200
            section: "right"
            // Right-group-shaped: hidden alerts cluster, hidden media, hidden
            // mic, visible audio, hidden battery — plus the separators between
            // them, so the collapse and cluster rules both run offscreen.
            entriesOverride: [
                {
                    id: "marchyo.clock"
                },
                {
                    id: "marchyo.media"
                },
                {
                    id: "marchyo.separator"
                },
                {
                    id: "marchyo.mic"
                },
                {
                    id: "marchyo.audio"
                },
                {
                    id: "marchyo.separator"
                },
                {
                    id: "marchyo.battery"
                }
            ]
            resolve: id => harnessRoot.harnessResolve[id] || null
            configure: (item, entry) => {}
            barWidth: 1280
        }
        PanelButton {
            x: 200
            text: "harness"
        }

        // Every bar widget; their bindings exercise the Commons singletons,
        // the Services singletons (SystemStats, Audio, Power, NetworkStatus,
        // Tooltip, NotificationState, PanelManager), and the native services.
        SessionWidget {
            x: 400
        }
        ClockWidget {
            x: 500
        }
        WorkspacesWidget {
            x: 620
            screenName: ""
        }
        BatteryWidget {
            x: 760
        }
        AudioWidget {
            x: 880
        }
        PowerProfileWidget {
            x: 1000
        }
        TrayWidget {
            x: 1080
        }
        CpuWidget {
            x: 1160
        }
        BluetoothWidget {
            y: 32
            x: 0
        }
        NetworkWidget {
            x: 120
            y: 32
        }
        CaffeineWidget {
            x: 260
            y: 32
        }
        DndWidget {
            x: 380
            y: 32
        }
        DictationWidget {
            x: 480
            y: 32
        }
        KeyboardLayoutWidget {
            x: 600
            y: 32
        }
        ThemeWidget {
            x: 720
            y: 32
        }
        MediaWidget {
            x: 840
            y: 32
        }
        PeripheralsWidget {
            x: 960
            y: 32
        }
        MicWidget {
            x: 1080
            y: 32
        }
    }

    // Self-exit: the check recipe watches the process and its log.
    Timer {
        interval: 2000
        running: true
        onTriggered: Qt.exit(0)
    }
}
