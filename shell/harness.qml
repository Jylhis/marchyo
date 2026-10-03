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

        // Flips a late-shown harness widget visible after load (see
        // cHarnessLate): the regression probe for a slot that starts hidden.
        property bool lateCond: false
        Timer {
            interval: 400
            running: true
            onTriggered: harnessRoot.lateCond = true
        }

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
                "marchyo.theme": cHarnessLate,
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
                shown: false
            }
        }
        // Starts hidden, then turns shown: true after load (harnessRoot.lateCond
        // flips on a timer). Reproduces the theme-toggle regression — a widget
        // hidden at the load instant that must reappear when its condition later
        // becomes true, which the old Loader-visible collapse froze forever.
        Component {
            id: cHarnessLate
            BarItem {
                text: "late"
                shown: harnessRoot.lateCond
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
            // them, so the collapse and cluster rules both run offscreen. The
            // trailing "theme" slot starts hidden and turns shown after load
            // (cHarnessLate): the regression guard for a slot that must reappear.
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
                },
                {
                    id: "marchyo.theme"
                }
            ]
            resolve: id => harnessRoot.harnessResolve[id] || null
            configure: (item, entry) => {}
            barWidth: 1280
        }

        // Assertions over the section above: widgets must actually RENDER, not
        // just load, and a slot hidden at load must reappear when its widget
        // turns shown (the theme-toggle regression). The Justfile check fails
        // on any ASSERT-FAIL line.
        Timer {
            interval: 1200
            running: true
            onTriggered: {
                const fail = msg => console.log("ASSERT-FAIL " + msg);
                // Each slot is now a wrapper Item (carries modelData) holding a
                // Loader; the wrapper's visibility is the collapse, the Loader's
                // item is the widget. Collect wrappers in model order.
                const kids = sectionSlots.children;
                let slots = [];
                for (let i = 0; i < kids.length; i++)
                    if (kids[i].modelData !== undefined)
                        slots.push(kids[i]);
                if (slots.length !== 8)
                    fail("expected 8 slot wrappers, got " + slots.length);
                // The loaded widget inside a wrapper (its Loader's item).
                const widgetOf = s => {
                    const sk = s.children;
                    for (let i = 0; i < sk.length; i++)
                        if (sk[i].toString().indexOf("QQuickLoader") >= 0)
                            return sk[i].item;
                    return null;
                };
                const shownOf = s => {
                    const w = widgetOf(s);
                    return w ? w.visible === true : false;
                };
                // clock: visible widget -> slot visible, item visible
                if (!slots[0].visible || !shownOf(slots[0]))
                    fail("visible widget collapsed: clock slot visible=" + slots[0].visible + " item=" + shownOf(slots[0]));
                // media (hidden): slot must be collapsed
                if (slots[1].visible)
                    fail("hidden widget did not collapse its slot: media");
                // separator 1 (idx 2): clock and audio flank the hidden
                // media+mic run, so exactly this one rule renders
                if (!slots[2].visible)
                    fail("separator between two populated clusters hidden (idx 2)");
                // mic (hidden): collapsed
                if (slots[3].visible)
                    fail("hidden widget did not collapse its slot: mic");
                // audio: visible
                if (!slots[4].visible || !shownOf(slots[4]))
                    fail("audio slot collapsed though visible");
                // separator 2 (idx 5): battery hidden AND the late theme slot is
                // shown by now, so audio and theme flank the hidden battery and
                // this rule must render
                if (!slots[5].visible)
                    fail("separator between audio and the late slot hidden (idx 5)");
                // battery (hidden): collapsed
                if (slots[6].visible)
                    fail("hidden widget did not collapse its slot: battery");
                // theme (started hidden, flipped shown after load): MUST be
                // visible now and its item MUST still be live (the bug froze it
                // invisible forever).
                if (!slots[7].visible || !shownOf(slots[7]))
                    fail("late-shown widget stayed collapsed: slot visible=" + slots[7].visible + " item=" + shownOf(slots[7]));
                for (let i = 0; i < slots.length; i++) {
                    const md = slots[i].modelData;
                    console.log("ASSERT-INFO idx=" + i + " id=" + (md ? md.id : "?") + " slot.visible=" + slots[i].visible + " item.visible=" + shownOf(slots[i]));
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
