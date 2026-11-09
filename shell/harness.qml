import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Bar
import qs.Launcher
import qs.Services
import "Commons/DevTools.js" as DevTools

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

        // The runtime style file and picker singletons load with the harness so
        // the assertions below see them settled.
        readonly property var styleService: RuntimeStyle
        readonly property var pickerService: Pickers

        // Pull in the lock service singleton (PAM state machine; the
        // WlSessionLock surface itself needs a compositor, like the panels).
        readonly property var lockService: Lock

        // The top-level types shell.qml declares.
        readonly property list<string> shellWindowFiles: [
            "Osd/Osd.qml",
            "Lock/LockScreen.qml",
            "Panels/AudioPanel.qml",
            "Panels/NetworkPanel.qml",
            "Panels/PowerPanel.qml",
            "Panels/MonitorPanel.qml",
            "Panels/DisplayPanel.qml",
            "Panels/WeatherPanel.qml",
            "Panels/ElsewhenPanel.qml",
            "Panels/TailscalePanel.qml",
            "Panels/WifiQrPanel.qml",
            "Panels/BluetoothPanel.qml",
            "Panels/SpeedtestPanel.qml",
            "Panels/DropboxPanel.qml",
            "Panels/GalleryPanel.qml",
            "Panels/WhatsNewPanel.qml",
            "Panels/SetupPanel.qml",
            "Panels/ImagePicker.qml",
            "Notifications/NotificationCenter.qml",
            "Panels/ControlCenter.qml",
            "Launcher/LauncherWindow.qml",
            "Overview/OverviewLayer.qml",
            "Notifications/NotificationDaemon.qml",
            "Polkit/PolkitDialog.qml",
            "Ui/TooltipWindow.qml"
        ]

        // Launcher providers are plain QtObjects, so they load offscreen even
        // though LauncherWindow (a PanelWindow) does not.
        readonly property list<QtObject> launcherProviders: [
            AppsProvider {},
            CalcProvider {},
            ClipboardProvider {},
            EmojiProvider {},
            FontProvider {},
            PowerProvider {},
            MenuProvider {
                id: harnessMenu
            },
            KeysProvider {
                id: harnessKeys
            },
            DmenuProvider {
                id: harnessDmenu
            },
            ThemeProvider {},
            WindowsProvider {}
        ]

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

        // The centre group: `center` sits at the exact middle and the two
        // flanking sections hang off its edges, so a late-appearing widget in
        // centerBegin never moves the anchor.
        Item {
            id: centerGroup
            x: 200
            y: 128
            width: 600
            height: 28

            BarSection {
                id: sectionCenter
                anchors.centerIn: parent
                section: "center"
                entriesOverride: [
                    {
                        id: "marchyo.clock"
                    }
                ]
                resolve: id => harnessRoot.harnessResolve[id] || null
                configure: (item, entry) => {}
            }
            BarSection {
                id: sectionCenterBegin
                anchors.right: sectionCenter.left
                anchors.verticalCenter: parent.verticalCenter
                section: "centerBegin"
                entriesOverride: [
                    {
                        id: "marchyo.theme"
                    }
                ]
                resolve: id => harnessRoot.harnessResolve[id] || null
                configure: (item, entry) => {}
            }
            BarSection {
                id: sectionCenterEnd
                anchors.left: sectionCenter.right
                anchors.verticalCenter: parent.verticalCenter
                section: "centerEnd"
                entriesOverride: [
                    {
                        id: "marchyo.audio"
                    }
                ]
                resolve: id => harnessRoot.harnessResolve[id] || null
                configure: (item, entry) => {}
            }
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
                // Centre group: the anchor stays centred while its neighbours
                // (the late widget on the begin side, audio on the end side)
                // grow outwards from its edges.
                sectionCenter.ensurePolished();
                sectionCenterBegin.ensurePolished();
                sectionCenterEnd.ensurePolished();
                if (Math.abs(sectionCenter.x + sectionCenter.width / 2 - centerGroup.width / 2) > 0.5)
                    fail("centre anchor moved: x=" + sectionCenter.x + " w=" + sectionCenter.width);
                if (Math.abs(sectionCenterBegin.x + sectionCenterBegin.width - sectionCenter.x) > 0.5)
                    fail("centerBegin does not end at the anchor's left edge");
                if (Math.abs(sectionCenterEnd.x - (sectionCenter.x + sectionCenter.width)) > 0.5)
                    fail("centerEnd does not start at the anchor's right edge");
                if (sectionCenterBegin.width <= 0 || sectionCenterEnd.width <= 0)
                    fail("centre neighbours collapsed: begin=" + sectionCenterBegin.width + " end=" + sectionCenterEnd.width);
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
                // Colors.surface.
                const segItem = widgetOf(segSlots[0]);
                const flatItem = widgetOf(slots[0]);
                if (!segItem || !Qt.colorEqual(segItem.hoverColor, sectionSegmented.segmentHover))
                    fail("segmented BarItem hover colour is not the section's: " + (segItem ? segItem.hoverColor : "no item"));
                if (Qt.colorEqual(sectionSegmented.segmentHover, sectionSegmented.segmentToneEven) || Qt.colorEqual(sectionSegmented.segmentHover, sectionSegmented.segmentToneOdd))
                    fail("segmented hover colour equals a segment tone: " + sectionSegmented.segmentHover);
                if (Qt.colorEqual(sectionSegmented.segmentToneEven, sectionSegmented.segmentToneOdd))
                    fail("segment tones are identical: " + sectionSegmented.segmentToneEven);
                if (!flatItem || !Qt.colorEqual(flatItem.hoverColor, Colors.surface))
                    fail("flat BarItem hover colour changed: " + (flatItem ? flatItem.hoverColor : "no item"));
                // The colour singletons must resolve to the theme, not to a
                // same-named type from another module (Qt 6.12 added a
                // QtQuick `Color` that shadowed the old Commons/Color).
                if (!Qt.colorEqual(Colors.text, Theme.palette.text) || !Qt.colorEqual(Colors.bg, Theme.palette.bg))
                    fail("Colors does not follow Theme.palette (singleton shadowed?): text=" + Colors.text + " bg=" + Colors.bg);
                // The lock gate and stranded-lock recovery must exist and
                // must not lock on their own.
                if (typeof Lock.screensReady !== "boolean" || typeof Lock.strandedResolved !== "boolean")
                    fail("Lock lost screensReady/strandedResolved");
                if (Lock.locked)
                    fail("Lock locked itself at startup without an orphaned compositor lock");
                if (typeof Screens.realCount !== "number")
                    fail("Screens.realCount missing");
                // The dev hooks are inert without their environment variables.
                if (Dev.enabled || Dev.noMotion || Dev.outputOverride !== "" || Dev.ipc.enabled)
                    fail("Dev hooks are active without MARCHYO_SHELL_* set");
                if (Screens.pin("DP-1") !== "DP-1" || Screens.pin("") !== "")
                    fail("Screens.pin changed an output without MARCHYO_SHELL_OUTPUT");
                if (Dev.surfaces() !== "{}" || Dev.setLauncherQuery("x") !== "closed" || Dev.settled() === "")
                    fail("Dev IPC functions are not inert");
                RuntimeStyle.apply("");
                if (Style.motionRuntimeOff || Style.duration(Style.motionFast) <= 0)
                    fail("durations are zero without MARCHYO_SHELL_NO_MOTION");
                if (DevTools.pickOutput("SHOT", ["DP-1", "SHOT"], "DP-1") !== "SHOT" || DevTools.pickOutput("SHOT", ["DP-1"], "DP-1") !== "DP-1")
                    fail("DevTools.pickOutput is wrong");
                // The string layer loads its catalogs; the dev tree bakes English.
                if (I18n.t("audio.title") !== "Audio")
                    fail("I18n.t(audio.title) = " + I18n.t("audio.title"));
                if (I18n.t("power.charger", 65) !== "Charger  65 W")
                    fail("I18n.t hole substitution failed");
                if (I18n.t("no.such.key") !== "no.such.key")
                    fail("I18n.t does not return the key for a missing key");
                if (I18n.tn("audio.applications", 2, 2) !== "2 applications")
                    fail("I18n.tn plural selection failed");
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
        UpdateWidget {
            x: 360
            y: 64
        }
        DiskWidget {
            x: 380
            y: 64
        }
        HealthWidget {
            x: 440
            y: 64
        }
        PanelSlider {
            x: 0
            y: 64
            width: 200
            value: 0.5
        }

        // The native Ui kit (Ui/*.qml): every control instantiated and driven
        // through its keyboard-facing API, then asserted after the settle.
        Item {
            id: kit
            y: 100
            width: 400
            height: 400

            property int clicks: 0
            property int toggles: 0
            property int picks: 0
            property int confirms: 0
            property string groupValue: "a"

            Button {
                id: kitButton
                text: "button"
                onClicked: kit.clicks++
            }
            ButtonGroup {
                id: kitGroup
                y: 30
                options: ["a", "b", "c"]
                value: kit.groupValue
                onChanged: v => kit.groupValue = v
            }
            Toggle {
                id: kitToggle
                y: 60
                label: "toggle"
                onToggled: kit.toggles++
            }
            FilterInput {
                id: kitFilter
                y: 100
                text: "abc"
            }
            Dropdown {
                id: kitDropdown
                y: 130
                options: [
                    {
                        value: "x",
                        label: "ex"
                    },
                    {
                        value: "y",
                        label: "why"
                    }
                ]
                value: "x"
                onActivated: kit.picks++
            }
            SearchableDropdown {
                id: kitSearch
                y: 170
                options: ["oslo", "osaka", "lima"]
            }
            PanelHero {
                y: 210
                title: "hero"
            }
            PanelSectionHeader {
                y: 250
                text: "section"
            }
            PanelSeparator {
                y: 270
                width: 100
            }
            PanelActionButton {
                y: 280
                text: "action"
            }
            PopupCard {
                y: 310
                title: "card"
                PopupMenuRow {
                    text: "row"
                    checked: true
                }
            }
            PointerMoveGate {
                id: kitGate
            }
            ConfirmDialog {
                id: kitDialog
                title: "dialog"
                onConfirmed: kit.confirms++
            }
        }

        Timer {
            interval: 900
            running: true
            onTriggered: {
                const fail = m => console.log("ASSERT-FAIL " + m);
                const states = ["normal", "hover", "focus", "selected", "pressed"];
                for (const st of states) {
                    const c = Style.control(st);
                    if (!c || c.borderWidth < 1 || c.fillAlpha <= 0)
                        fail("Style.control(" + st + ") is incomplete");
                }
                if (Style.control("focus").borderWidth <= Style.control("normal").borderWidth)
                    fail("the focus ring is not wider than the hairline");

                if (Style.duration(Style.motionFast) <= 0)
                    fail("Style.duration is 0 with motion on");
                Style.motionRuntimeOff = true;
                if (Style.duration(Style.motionFast) !== 0)
                    fail("Style.duration ignores the runtime reduce-motion switch");
                Style.motionRuntimeOff = false;
                Style.compositorAnimationsOff = true;
                if (Style.duration(Style.motionFast) !== 0)
                    fail("Style.duration ignores Hyprland animations:enabled");
                Style.compositorAnimationsOff = false;

                kitButton.activate();
                if (kit.clicks !== 1)
                    fail("Button.activate did not click");
                kitToggle.activate();
                if (kit.toggles !== 1)
                    fail("Toggle.activate did not emit toggled");
                kitGroup.step(1);
                if (kit.groupValue !== "b")
                    fail("ButtonGroup.step did not move the choice");

                kitDropdown.openList();
                if (!kitDropdown.open)
                    fail("Dropdown.openList did not open");
                kitDropdown.pick(1);
                if (kitDropdown.value !== "y" || kit.picks !== 1 || kitDropdown.open)
                    fail("Dropdown.pick did not choose and close");
                kitSearch.openList();
                kitSearch.query = "os";
                if (kitSearch.shown.length !== 2)
                    fail("SearchableDropdown did not filter to two rows");

                kitSearch.openList();
                kitSearch.closeList();
                if (kitSearch.filterFocused)
                    fail("closing a searchable dropdown left the filter focused");

                kitFilter.clear();
                if (kitFilter.text !== "")
                    fail("FilterInput.clear left text behind");

                kitDialog.open = true;
                kitDialog.confirm();
                if (kit.confirms !== 1 || kitDialog.open)
                    fail("ConfirmDialog.confirm did not emit and close");
                if (kitDialog.activeFocus || kitDialog.enabled)
                    fail("a closed ConfirmDialog is still focusable");

                kitGate.hold();
                if (Pointer.moved)
                    fail("PointerMoveGate.hold left the pointer marked as moved");
                kitGate.release();

                // Runtime style: a parsed style.json lands in Style, and an
                // empty file restores the baked defaults.
                RuntimeStyle.apply('{"reduceMotion":true,"uiFont":"Harness Sans","barPosition":"bottom","barBackground":"clear"}');
                if (!Style.motionRuntimeOff || Style.duration(Style.motionFast) !== 0)
                    fail("RuntimeStyle reduceMotion did not reach Style.duration");
                if (Style.fontFamily !== "Harness Sans")
                    fail("RuntimeStyle uiFont did not reach Style.fontFamily: " + Style.fontFamily);
                if (!Style.barBottom || Style.barAlpha !== 0)
                    fail("RuntimeStyle bar switches did not reach Style: " + Style.barPosition + " " + Style.barAlpha);
                RuntimeStyle.apply("{}");
                if (Style.motionRuntimeOff || Style.fontFamily !== Style.baseFontFamily || Style.barBottom || Style.barBackground !== "")
                    fail("RuntimeStyle did not restore the baked defaults");

                // Picker data and thumbnails: rows are lists, an unknown image
                // falls back to itself, a generated thumbnail replaces it.
                if (!Array.isArray(Pickers.rows("themes")) || !Array.isArray(Pickers.rows("backgrounds")))
                    fail("Pickers.rows is not a list");
                if (Thumbnails.sourceFor("") !== "" || Thumbnails.sourceFor("/w/a.png") !== "file:///w/a.png")
                    fail("Thumbnails.sourceFor did not fall back to the full image");
                Thumbnails.take("/w/a.png\t/c/t.png");
                if (Thumbnails.sourceFor("/w/a.png") !== "file:///c/t.png")
                    fail("Thumbnails.take did not register the thumbnail");
                Thumbnails.map = ({});
            }
        }

        Timer {
            interval: 1100
            running: true
            onTriggered: {
                const fail = m => console.log("ASSERT-FAIL " + m);
                // The shell's windows cannot be created offscreen, but
                // compiling each file still catches QML compile errors.
                for (const f of harnessRoot.shellWindowFiles) {
                    const w = Qt.createComponent(Qt.resolvedUrl(f));
                    const stray = w.errorString().split("\n").filter(l => l.trim() !== "" && l.indexOf("No PanelWindow backend loaded") === -1 && !/Type \w+ unavailable/.test(l));
                    if (stray.length > 0)
                        fail(f + " did not compile: " + stray.join("; "));
                }

                // The menu, cheat sheet and dmenu providers load without their
                // data files and answer with empty result lists.
                if (!Array.isArray(harnessMenu.results) || !Array.isArray(harnessKeys.results) || !Array.isArray(harnessDmenu.results))
                    fail("menu providers did not produce result lists");
                Launcher.openMenu("appearance.theme");
                if (Launcher.mode !== "menu" || Launcher.menuRoute !== "appearance.theme" || !Launcher.menuUp() || Launcher.menuRoute !== "appearance")
                    fail("Launcher menu route stack misbehaves: " + Launcher.menuRoute);
                Launcher.close();
                if (Launcher.menuRoute !== "")
                    fail("closing the launcher kept the menu route");
            }
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

    Component {
        id: ghostC
        GhostNotification {}
    }

    FileView {
        id: tokenWriter
        path: Quickshell.statePath("harness-notify-token")
        blockWrites: true
        printErrors: false
    }

    // NotificationState with restored-style notifications: DND pass and hold,
    // history redaction and the transient hint, and the exec-token gate.
    Timer {
        interval: 1200
        running: true
        onTriggered: {
            const fail = m => console.log("ASSERT-FAIL " + m);
            const NS = NotificationState;
            const mk = (app, summary, hints) => ghostC.createObject(null, {
                    "appName": app,
                    "summary": summary,
                    "body": "",
                    "hints": hints,
                    "urgency": 1
                });
            NS.nonceDir = Quickshell.statePath("harness-nonce");
            const nonce = (hex, content) => {
                tokenWriter.path = NS.nonceDir + "/" + hex;
                tokenWriter.setText(content !== undefined ? content : hex);
                return hex;
            };
            const tok = h => ({
                    "marchyo-token": h
                });
            const argvOf = n => JSON.stringify(NS.execArgvOf(n));
            const n1 = nonce("ab".repeat(32));
            if (NS.tokenOk({}) || NS.tokenOk(tok("short")) || NS.tokenOk(tok("ef".repeat(32))))
                fail("a missing, short or unwritten token was accepted");
            nonce("cd".repeat(32), "not-the-name");
            if (NS.tokenOk(tok("cd".repeat(32))))
                fail("a token file with other content was accepted");
            if (!NS.tokenOk(tok(n1)))
                fail("a written one-time token was not accepted");
            if (NS.tokenOk(tok(n1)))
                fail("a one-time token was accepted twice");
            nonce(n1);
            if (NS.tokenOk(tok(n1)))
                fail("a spent token was accepted again after its file came back");

            // A trusted card, then an update from another bus client that relabels
            // it: Quickshell applies replaces_id in place, without a new signal.
            const exec = (argv, token) => ({
                    "marchyo-exec-argv": JSON.stringify(argv),
                    "marchyo-token": token
                });
            NS.clearAll();
            NS.clearHistory();
            const card = mk("marchyo-action", "Reboot", exec(["a", "b"], nonce("11".repeat(32))));
            NS.show(card);
            if (argvOf(card) !== "[\"a\",\"b\"]")
                fail("a trusted exec argv was not honoured");
            card.summary = "Download finished";
            card.hints = {
                "marchyo-exec-argv": "[\"evil\"]"
            };
            NS.flushRefresh();
            if (NS.execArgvOf(card) !== null || NS.deedsOf(card).length !== 0)
                fail("an untrusted relabel kept or gained a command");
            if (NS.history[0].summary !== "Download finished")
                fail("the history entry did not follow the update");

            // The same relabel that replays the card's old hints and token.
            const card2 = mk("marchyo-action", "Reboot", exec(["a", "b"], nonce("12".repeat(32))));
            NS.show(card2);
            card2.summary = "Download finished";
            NS.flushRefresh();
            if (NS.execArgvOf(card2) !== null)
                fail("a spent token kept a command alive across a text-only update");

            // `marchyo notify -r`: a new token with a new command takes over.
            const card3 = mk("marchyo-action", "Old", exec(["old"], nonce("13".repeat(32))));
            NS.show(card3);
            card3.summary = "New";
            card3.hints = exec(["new", "x"], nonce("14".repeat(32)));
            NS.flushRefresh();
            if (argvOf(card3) !== "[\"new\",\"x\"]")
                fail("a trusted replacement did not install its new command");
            card3.hints = {};
            NS.flushRefresh();
            if (NS.execArgvOf(card3) !== null)
                fail("a replacement without a command kept the old one");

            // A glyph is drawn only for a token-proved sender.
            const glyph = (summary, token) => mk("Chat", summary, Object.assign({
                    "marchyo-glyph": "G"
                }, token ? tok(token) : {}));
            const plain = glyph("plain");
            const proved = glyph("proved", nonce("15".repeat(32)));
            NS.show(plain);
            NS.show(proved);
            if (NS.rowOf(plain).glyph !== "" || NS.rowOf(proved).glyph !== "G")
                fail("the glyph was not gated on the token");

            // A held notification keeps its vetted command through do-not-disturb.
            NS.clearAll();
            NS.setDnd(true);
            const held = mk("Chat", "held", exec(["h"], nonce("16".repeat(32))));
            NS.show(held);
            if (NS.queued.length !== 1)
                fail("do-not-disturb did not hold a notification with a command");
            NS.setDnd(false);
            if (argvOf(held) !== "[\"h\"]")
                fail("a held notification lost its command when released");

            // A restored toast never carries a command, even a well-formed one.
            NS.clearAll();
            NS.restoreLive("[{\"key\":\"evil\",\"app\":\"marchyo-action\",\"summary\":\"Reboot\",\"execArgv\":\"[\\\"sh\\\",\\\"-c\\\",\\\"id\\\"]\"}]");
            if (NS.entries.length !== 1 || NS.execArgvOf(NS.entries[0].n) !== null)
                fail("a restored toast carried a command");
            NS.clearAll();
            NS.setDnd(true);
            const unproved = {
                "marchyo-exec-argv": "[\"marchyo\",\"shell\",\"open\",\"setup\"]",
                "marchyo-token": "0".repeat(64)
            };
            const own = mk("marchyo-action", "Welcome", unproved);
            NS.show(own);
            if (NS.entries.length !== 1)
                fail("marchyo-action did not pass do-not-disturb");
            if (NS.execArgvOf(own) !== null)
                fail("an exec argv was honoured without the session token");
            const code = mk("Chat", "Your verification code is 482913", {});
            NS.show(code);
            if (JSON.stringify(NS.history[0]).indexOf("482913") >= 0)
                fail("a verification code reached the history");
            const quiet = mk("Chat", "quiet", {});
            NS.show(quiet);
            if (!NS.queued.some(q => q.n === quiet))
                fail("do-not-disturb did not hold a plain notification");
            if (NS.history[0].silenced !== true)
                fail("a silenced row is not marked in the history");
            const count = NS.history.length;
            NS.show(mk("Chat", "transient", {
                "transient": true
            }));
            if (NS.history.length !== count)
                fail("a transient notification was recorded");
            NS.setDnd(false);
            NS.clearAll();
            NS.restoreLive("[{\"key\":\"r1\",\"app\":\"Chat\",\"summary\":\"back\",\"urgency\":1},{\"key\":\"r2\",\"app\":\"Disk\",\"summary\":\"full\",\"urgency\":2}]");
            if (NS.entries.length !== 2)
                fail("restored live toasts: expected 2, got " + NS.entries.length);
            else if (NS.entries[0].n.summary !== "full" || NS.entries[0].deadline !== 0)
                fail("a restored critical toast must stay until dismissed");
            else if (NS.entries[1].deadline <= Date.now() || NS.entries[1].deadline > Date.now() + 21000)
                fail("a restored toast does not get the 20 s grace");
            NS.clearAll();
            NS.clearHistory();
            console.log("ASSERT-NOTIFY-DONE");
        }
    }

    // Self-exit: the check recipe watches the process and its log.
    Timer {
        interval: 2000
        running: true
        onTriggered: Qt.exit(0)
    }
}
