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
                "marchyo.battery": cHarnessHidden,
                "marchyo.separator": cHarnessSeparator
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
        Component {
            id: cHarnessSeparator
            BarSeparator {}
        }
        BarSection {
            id: sectionSlots
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

        // Assertions over the section above: widgets must actually RENDER,
        // not just load (the empty-bar regression: Loader's load-time
        // visibility write once poisoned every widget invisible while the
        // tree still parsed and bound cleanly). The Justfile check fails on
        // any ASSERT-FAIL line.
        Timer {
            interval: 1200
            running: true
            onTriggered: {
                const fail = msg => console.log("ASSERT-FAIL " + msg);
                const kids = sectionSlots.children;
                // children: [loader x7, Repeater] — Loaders in model order.
                let loaders = [];
                for (let i = 0; i < kids.length; i++)
                    if (kids[i].toString().indexOf("QQuickLoader") >= 0)
                        loaders.push(kids[i]);
                if (loaders.length !== 7)
                    fail("expected 7 slot Loaders, got " + loaders.length);
                // clock: visible widget -> slot visible, item visible
                if (!loaders[0] || !loaders[0].visible || !loaders[0].item.visible)
                    fail("visible widget collapsed: clock slot visible=" + loaders[0].visible + " item=" + loaders[0].item.visible);
                // media (hidden): slot must be collapsed
                if (loaders[1].visible)
                    fail("hidden widget did not collapse its slot: media");
                // separator 1 (idx 2): clock and audio flank the hidden
                // media+mic run, so exactly this one rule renders
                if (!loaders[2].visible)
                    fail("separator between two populated clusters hidden (idx 2)");
                // mic (hidden): collapsed
                if (loaders[3].visible)
                    fail("hidden widget did not collapse its slot: mic");
                // audio: visible
                if (!loaders[4].visible || !loaders[4].item.visible)
                    fail("audio slot collapsed though visible");
                // separator 2 (idx 5): battery hidden -> trailing cluster
                // empty -> rule hidden
                if (loaders[5].visible)
                    fail("trailing separator visible before collapsed battery");
                // battery (hidden): collapsed
                if (loaders[6].visible)
                    fail("hidden widget did not collapse its slot: battery");
                for (let i = 0; i < loaders.length; i++) {
                    const md = loaders[i].modelData;
                    console.log("ASSERT-INFO idx=" + i + " id=" + (md ? md.id : "?") + " loader.visible=" + loaders[i].visible + " item.visible=" + (loaders[i].item ? loaders[i].item.visible : "null"));
                }
                console.log("ASSERT-DONE");
            }
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
