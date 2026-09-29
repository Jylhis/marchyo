import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.Commons
import qs.Bar
import qs.Osd
import qs.Ui
import qs.Panels
import qs.Launcher
import qs.Notifications
import qs.Lock
import qs.Services

// A Jylhis-themed top bar plus the shell surfaces (OSD, panels, lock,
// notifications, launcher), composed from qs.Bar widgets backed by qs.Ui
// primitives and the qs.Commons singletons. The bar layout is data-driven from
// Commons/ShellConfig (a generated, read-only ~/.config/marchyo/shell.json;
// the default reproduces the historical static order). Widget ids resolve to
// first-party Components in `barComponents` below, or to plugin bar-widgets via
// Commons/PluginIndex — the build-time Option A plugin model (Nix-declared,
// store-baked; no runtime discovery). A single stock IpcHandler drives runtime
// actions; there is no custom bus. See plans/shell.md.
ShellRoot {
    id: shell

    // Bar visibility, toggled over IPC (SUPER+SHIFT+SPACE). Replaces waybar's
    // SIGUSR1 show/hide; one property drives every per-screen bar below.
    property bool barVisible: true

    // Widget-id -> Component map for the data-driven bar. First-party widgets
    // live here; plugin bar-widgets are resolved separately (Commons/PluginIndex)
    // in componentFor(). Ids mirror the default layout in Commons/ShellConfig.
    readonly property var barComponents: ({
            "marchyo.session": cSession,
            "marchyo.workspaces": cWorkspaces,
            "marchyo.activeWindow": cActiveWindow,
            "marchyo.clock": cClock,
            "marchyo.screenRecording": cScreenRecording,
            "marchyo.nightLight": cNightLight,
            "marchyo.reminders": cReminders,
            "marchyo.tailscale": cTailscale,
            "marchyo.weather": cWeather,
            "marchyo.tray": cTray,
            "marchyo.media": cMedia,
            "marchyo.dictation": cDictation,
            "marchyo.caffeine": cCaffeine,
            "marchyo.theme": cTheme,
            "marchyo.dnd": cDnd,
            "marchyo.keyboardLayout": cKeyboardLayout,
            "marchyo.bluetooth": cBluetooth,
            "marchyo.network": cNetwork,
            "marchyo.mic": cMic,
            "marchyo.audio": cAudio,
            "marchyo.cpu": cCpu,
            "marchyo.powerProfile": cPowerProfile,
            "marchyo.peripherals": cPeripherals,
            "marchyo.battery": cBattery
        })

    Component {
        id: cSession
        SessionWidget {}
    }
    Component {
        id: cWorkspaces
        WorkspacesWidget {}
    }
    Component {
        id: cActiveWindow
        ActiveWindowWidget {}
    }
    Component {
        id: cClock
        ClockWidget {}
    }
    Component {
        id: cScreenRecording
        ScreenRecordingWidget {}
    }
    Component {
        id: cNightLight
        NightLightWidget {}
    }
    Component {
        id: cReminders
        RemindersWidget {}
    }
    Component {
        id: cTailscale
        TailscaleWidget {}
    }
    Component {
        id: cWeather
        WeatherWidget {}
    }
    Component {
        id: cTray
        TrayWidget {}
    }
    Component {
        id: cMedia
        MediaWidget {}
    }
    Component {
        id: cDictation
        DictationWidget {}
    }
    Component {
        id: cCaffeine
        CaffeineWidget {}
    }
    Component {
        id: cTheme
        ThemeWidget {}
    }
    Component {
        id: cDnd
        DndWidget {}
    }
    Component {
        id: cKeyboardLayout
        KeyboardLayoutWidget {}
    }
    Component {
        id: cBluetooth
        BluetoothWidget {}
    }
    Component {
        id: cNetwork
        NetworkWidget {}
    }
    Component {
        id: cMic
        MicWidget {}
    }
    Component {
        id: cAudio
        AudioWidget {}
    }
    Component {
        id: cCpu
        CpuWidget {}
    }
    Component {
        id: cPowerProfile
        PowerProfileWidget {}
    }
    Component {
        id: cPeripherals
        PeripheralsWidget {}
    }
    Component {
        id: cBattery
        BatteryWidget {}
    }

    // Resolve a bar-layout id to a Component: first-party map, then plugins.
    function componentFor(id: string): Component {
        if (shell.barComponents[id])
            return shell.barComponents[id];
        return PluginIndex.barWidgetComponent(id);
    }

    // Apply a layout entry to a freshly-loaded widget: give per-monitor widgets
    // their screen (only WorkspacesWidget declares screenName), and hand any
    // widget its per-entry settings object if it accepts one.
    function applyWidget(item, entry, screenName): void {
        if (!item)
            return;
        if (typeof item.screenName === "string")
            item.screenName = screenName;
        if (entry.settings !== undefined && typeof item.settings !== "undefined")
            item.settings = entry.settings;
    }

    // On-screen display for volume/brightness/mic-mute (replaces SwayOSD). Reacts
    // natively to Pipewire and the backlight sysfs node — no external poke.
    Osd {
        id: osd
    }

    // The lock surface (Phase 4): Services/Lock owns the PAM state machine;
    // this is the seat's one compositor-level WlSessionLock. A static child,
    // never a Loader — see Lock/LockScreen.qml for the protocol hazard.
    LockScreen {}

    // Summonable panels: toggled in-process from their bar widgets via the shared
    // PanelManager (mutually exclusive). Each is a layer-shell overlay that only
    // materialises a surface while open.
    AudioPanel {}
    NetworkPanel {}
    PowerPanel {}
    MonitorPanel {}
    WeatherPanel {}
    TailscalePanel {}
    WifiQrPanel {}
    NotificationCenter {}

    // Launcher: apps / emoji / clipboard surface, summoned over IPC by the
    // Super+R / Super+period / Super+Ctrl+V binds (see Keybind summons).
    LauncherWindow {}

    // Notifications: owns org.freedesktop.Notifications (replaces mako) and draws
    // its own top-right toast stack. DND lives in the shared NotificationState
    // singleton, toggled by the bar's DndWidget and the IPC below.
    NotificationDaemon {}

    // The one tooltip surface: hover text from any BarItem / tray icon, rendered
    // below the bar on the hovered item's screen (Services/Tooltip holds the state).
    TooltipWindow {}

    // Keybind bridge: Hyprland binds reach the already-running shell through
    // `marchyo-shell ipc -n call -- shell <fn> [args]` (the wrapper bakes its own
    // -p, so it self-targets the running instance). A single stock IpcHandler — no
    // custom bus, no plugin registry (see plans/shell.md). Panel summons mirror the
    // in-process bar-widget clicks; the OSD poke is a fallback for the brightness
    // case the native watcher can't cover on some hosts.
    IpcHandler {
        target: "shell"

        function togglePanel(id: string): string {
            PanelManager.toggle(id);
            return "ok";
        }

        function openPanel(id: string): string {
            PanelManager.open(id);
            return "ok";
        }

        function closePanels(): string {
            PanelManager.close();
            return "ok";
        }

        function toggleDnd(): string {
            NotificationState.toggleDnd();
            return NotificationState.dnd ? "on" : "off";
        }

        function setDnd(on: string): string {
            NotificationState.setDnd(on === "true" || on === "on" || on === "1");
            return NotificationState.dnd ? "on" : "off";
        }

        function clearNotifications(): string {
            NotificationState.clearAll();
            return "ok";
        }

        function dismissLast(): string {
            NotificationState.dismissLast();
            return "ok";
        }

        function toggleNotifications(): string {
            PanelManager.toggle("notifications");
            return "ok";
        }

        function clearHistory(): string {
            NotificationState.clearHistory();
            return "ok";
        }

        function toggleBar(): string {
            shell.barVisible = !shell.barVisible;
            return shell.barVisible ? "on" : "off";
        }

        function setBar(on: string): string {
            shell.barVisible = on === "true" || on === "on" || on === "1";
            return shell.barVisible ? "on" : "off";
        }

        function osdShow(label: string, percent: string, hasBar: string): string {
            osd.show(label, parseInt(percent) || 0, hasBar !== "false");
            return "ok";
        }

        function lock(): string {
            Lock.lock();
            return "locked";
        }

        function lockState(): string {
            return Lock.locked ? "locked" : "unlocked";
        }

        function toggleLauncher(mode: string): string {
            Launcher.toggle(mode);
            return Launcher.open ? "on" : "off";
        }

        function openLauncher(mode: string): string {
            Launcher.openAs(mode);
            return "on";
        }

        function closeLauncher(): string {
            Launcher.close();
            return "ok";
        }

        function ping(): string {
            return "ok";
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWin
            required property var modelData
            readonly property string screenName: modelData.name
            screen: modelData
            visible: shell.barVisible

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Style.barHeight
            color: Color.background

            // Three anchored sections driven by ShellConfig.bar: left and right
            // groups, plus a centered group (the clock by default). Each entry's
            // id resolves through componentFor(); a Loader instantiates it and
            // applyWidget() wires per-monitor screen + per-entry settings.
            Item {
                anchors.fill: parent

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    Repeater {
                        model: ShellConfig.bar.left

                        Loader {
                            required property var modelData
                            sourceComponent: shell.componentFor(modelData.id)
                            onLoaded: shell.applyWidget(item, modelData, barWin.screenName)
                        }
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.spacing

                    Repeater {
                        model: ShellConfig.bar.center

                        Loader {
                            required property var modelData
                            sourceComponent: shell.componentFor(modelData.id)
                            onLoaded: shell.applyWidget(item, modelData, barWin.screenName)
                        }
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    Repeater {
                        model: ShellConfig.bar.right

                        Loader {
                            required property var modelData
                            sourceComponent: shell.componentFor(modelData.id)
                            onLoaded: shell.applyWidget(item, modelData, barWin.screenName)
                        }
                    }
                }
            }
        }
    }
}
