import QtQuick
import Quickshell
import qs.Commons
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
        height: 96

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
        // Entries shared by the flat and segmented sections below.
        readonly property var harnessEntries: [
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
        BarSection {
            id: sectionSlots
            x: 200
            section: "right"
            // Right-group-shaped: hidden alerts cluster, hidden media, hidden
            // mic, visible audio, hidden battery — plus the separators between
            // them, so the collapse and cluster rules both run offscreen. The
            // trailing "theme" slot starts hidden and turns shown after load
            // (cHarnessLate): the regression guard for a slot that must reappear.
            entriesOverride: harnessRoot.harnessEntries
            resolve: id => harnessRoot.harnessResolve[id] || null
            configure: (item, entry) => {}
            barWidth: 1280
        }

        // The same section in the segmented style, offscreen beside the flat
        // one: its slots must sit exactly where the flat section's do, and its
        // background layer must draw one segment per populated cluster.
        BarSection {
            id: sectionSegmented
            x: 200
            y: 64
            section: "right"
            barStyle: "segmented"
            entriesOverride: harnessRoot.harnessEntries
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
                // Segmented style: identical slot geometry, and three
                // segments (clock | audio | late theme) joined at the two
                // rendered separators.
                // The harness Item has no window, so nothing runs the layout
                // polish pass on its own: settle both rows first.
                sectionSlots.ensurePolished();
                sectionSegmented.ensurePolished();
                if (sectionSlots.segments.length !== 0)
                    fail("flat section computed segments: " + sectionSlots.segments.length);
                if (sectionSegmented.implicitWidth !== sectionSlots.implicitWidth)
                    fail("segmented section width " + sectionSegmented.implicitWidth + " != flat " + sectionSlots.implicitWidth);
                const segKids = sectionSegmented.children;
                let segSlots = [];
                for (let i = 0; i < segKids.length; i++)
                    if (segKids[i].modelData !== undefined)
                        segSlots.push(segKids[i]);
                if (segSlots.length !== slots.length)
                    fail("segmented section has " + segSlots.length + " slots, flat has " + slots.length);
                for (let i = 0; i < Math.min(segSlots.length, slots.length); i++) {
                    const a = slots[i];
                    const b = segSlots[i];
                    if (a.x !== b.x || a.width !== b.width || a.visible !== b.visible)
                        fail("segmented slot " + i + " moved: flat x=" + a.x + " w=" + a.width + " segmented x=" + b.x + " w=" + b.width);
                }
                const segs = sectionSegmented.segments;
                if (segs.length !== 3)
                    fail("expected 3 segments, got " + segs.length);
                else {
                    if (segs[0].joinLeft || !segs[0].joinRight || !segs[1].joinLeft || !segs[1].joinRight || !segs[2].joinLeft || segs[2].joinRight)
                        fail("segment join flags wrong: " + JSON.stringify(segs));
                    if (segs[0].right !== segs[1].left || segs[1].right !== segs[2].left)
                        fail("segments do not meet at the separators: " + JSON.stringify(segs));
                    if (!(segs[0].depthRight > 0) || segs[1].depthLeft !== segs[0].depthRight)
                        fail("join depth not shared across a join: " + JSON.stringify(segs));
                    if (segs[2].right !== sectionSegmented.implicitWidth)
                        fail("last segment does not reach the section end: " + segs[2].right + " " + JSON.stringify(segs) + " w=" + sectionSegmented.implicitWidth);
                }
                // Hover on the segmented bar: a BarItem inside the segmented
                // section takes the section's hover colour, which differs from
                // both segment tones; one in the flat section keeps
                // Color.surface.
                const segItem = widgetOf(segSlots[0]);
                const flatItem = widgetOf(slots[0]);
                if (!segItem || !Qt.colorEqual(segItem.hoverColor, sectionSegmented.segmentHover))
                    fail("segmented BarItem hover colour is not the section's: " + (segItem ? segItem.hoverColor : "no item"));
                if (Qt.colorEqual(sectionSegmented.segmentHover, sectionSegmented.segmentToneEven) || Qt.colorEqual(sectionSegmented.segmentHover, sectionSegmented.segmentToneOdd))
                    fail("segmented hover colour equals a segment tone: " + sectionSegmented.segmentHover);
                if (Qt.colorEqual(sectionSegmented.segmentToneEven, sectionSegmented.segmentToneOdd))
                    fail("segment tones are identical: " + sectionSegmented.segmentToneEven);
                if (!flatItem || !Qt.colorEqual(flatItem.hoverColor, Color.surface))
                    fail("flat BarItem hover colour changed: " + (flatItem ? flatItem.hoverColor : "no item"));
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
        ControlCenterWidget {
            x: 1180
            y: 32
        }
        CameraWidget {
            x: 220
            y: 64
        }
        LockKeysWidget {
            x: 300
            y: 64
        }
        PanelSlider {
            x: 0
            y: 64
            width: 200
            value: 0.5
        }

        // The Control Center tile model (Services/QuickToggles): every entry
        // carries the full interface the tiles bind to.
        Timer {
            interval: 1000
            running: true
            onTriggered: {
                const entries = QuickToggles.all;
                if (!entries || entries.length === 0)
                    console.log("ASSERT-FAIL QuickToggles.all is empty");
                const keys = {};
                for (let i = 0; i < entries.length; i++) {
                    const t = entries[i];
                    if (typeof t.key !== "string" || t.key === "" || keys[t.key])
                        console.log("ASSERT-FAIL QuickToggles entry " + i + " has a missing or duplicate key");
                    keys[t.key] = true;
                    for (const f of ["icon", "label", "status", "detail"])
                        if (typeof t[f] !== "string")
                            console.log("ASSERT-FAIL QuickToggles." + t.key + "." + f + " is not a string");
                    for (const f of ["active", "available"])
                        if (typeof t[f] !== "boolean")
                            console.log("ASSERT-FAIL QuickToggles." + t.key + "." + f + " is not a bool");
                    if (typeof t.toggle !== "function")
                        console.log("ASSERT-FAIL QuickToggles." + t.key + ".toggle is not a function");
                }
            }
        }
    }

    // Self-exit: the check recipe watches the process and its log.
    Timer {
        interval: 2000
        running: true
        onTriggered: Qt.exit(0)
    }
}
