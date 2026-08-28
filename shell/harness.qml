import QtQuick
import Quickshell
import Quickshell.Io
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
        width: 1280
        height: 64

        // Ui primitives.
        BarItem {
            x: 0
            text: "harness"
            tooltipText: "harness tooltip"
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
    }

    // Self-exit: the check recipe watches the process and its log.
    Timer {
        interval: 2000
        running: true
        onTriggered: Qt.exit(0)
    }
}
