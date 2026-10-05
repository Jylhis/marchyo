import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.Commons
import qs.Bar
import qs.Osd
import qs.Ui
import qs.Panels
import qs.Launcher
import qs.Notifications
import qs.Lock
import qs.Services
// omarchy plugin compat host API (shell/compat). Namespaced so its BarWidget /
// Panel / Style / Color do not collide with marchyo's own qs.Ui / qs.Commons.
import qs.compat.Ui as Plugin

// A Jylhis-themed top bar plus the shell surfaces (OSD, panels, lock,
// notifications, launcher), composed from qs.Bar widgets backed by qs.Ui
// primitives and the qs.Commons singletons. The bar layout is data-driven from
// Commons/ShellConfig (a generated, read-only ~/.config/marchyo/shell.json;
// the default reproduces the historical static order). Widget ids resolve to
// first-party Components in `barComponents` below, or to plugin bar-widgets via
// Commons/PluginIndex — the build-time Option A plugin model (Nix-declared,
// store-baked; no runtime discovery). A single stock IpcHandler drives runtime
// actions; there is no custom bus. See shell/README.md.
ShellRoot {
    id: shell

    // Bar visibility, toggled over IPC (SUPER+SHIFT+SPACE). One property drives
    // every per-screen bar below.
    property bool barVisible: true

    // Widget-id -> Component map for the data-driven bar. First-party widgets
    // live here; plugin bar-widgets are resolved separately (Commons/PluginIndex)
    // in componentFor(). Ids mirror the default layout in Commons/ShellConfig.
    readonly property var barComponents: ({
            "marchyo.separator": cSeparator,
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
        id: cSeparator
        BarSeparator {}
    }
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

    // Per-widget host facade handed to an omarchy-compat plugin bar widget as
    // its `bar`. Scalars mirror marchyo's bar (colors, font, geometry); shared
    // popout state and click-target registry delegate to Services/PluginPopout;
    // operations route to marchyo services. Created per plugin widget in
    // applyWidget() so `pluginId`/`moduleName` carry that widget's id.
    Component {
        id: cPluginBar
        Plugin.PluginBarApi {
            foreground: Color.text
            barForeground: Color.text
            background: Color.background
            urgent: Color.statusErr
            fontFamily: Style.fontFamily
            position: "top"
            vertical: false
            barSize: Style.barHeight
            transparent: false
            foregroundAnimationEnabled: true
            activePopout: PluginPopout.activePopout
            clickTargets: PluginPopout.clickTargets
            _showTooltip: (target, text) => Tooltip.show(text, target)
            _hideTooltip: target => Tooltip.hide()
            _run: command => Quickshell.execDetached(["sh", "-lc", command])
            _requestPopout: owner => PluginPopout.requestPopout(owner)
            _releasePopout: owner => PluginPopout.releasePopout(owner)
            _registerClickTarget: target => PluginPopout.registerClickTarget(target)
            _unregisterClickTarget: target => PluginPopout.unregisterClickTarget(target)
            _switchPanelFrom: (owner, direction) => PluginPopout.switchPanelFrom(owner, direction)
            _targetBelongsToWindow: (target, window) => PluginPopout.targetBelongsToWindow(target, window)
            _moduleWidgets: id => PluginPopout.moduleWidgets(id)
        }
    }

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
        // omarchy-compat plugin widgets expose `bar` + `moduleName` (see
        // shell/compat/Ui/BarWidget.qml, Panel.qml). Give them their id and a
        // freshly-created PluginBarApi facade, parented to the widget so it is
        // torn down with it. First-party BarItem widgets have neither property
        // and are left untouched.
        if (typeof item.moduleName === "string" && typeof item.bar !== "undefined") {
            item.moduleName = entry.id;
            // Merge the runtime settings overlay (omarchy-bar writes) over the
            // widget's inline layout settings, so a setting a plugin persists
            // from its popup survives a shell restart.
            const overlay = ShellConfig.pluginSettings ? ShellConfig.pluginSettings[entry.id] : undefined;
            if (overlay !== undefined && typeof item.settings !== "undefined")
                item.settings = Object.assign({}, entry.settings || {}, overlay);
            if (!item.bar)
                item.bar = cPluginBar.createObject(item, {
                    "pluginId": entry.id,
                    "moduleName": entry.id
                });
        }
    }

    // On-screen display for volume/brightness/mic-mute. Reacts natively to
    // Pipewire and the backlight sysfs node, no external poke.
    Osd {
        id: osd
    }

    // The lock surface: Services/Lock owns the PAM state machine; this is the
    // seat's one compositor-level WlSessionLock. A static child, never a Loader,
    // see Lock/LockScreen.qml for the protocol hazard.
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

    // Notifications: owns org.freedesktop.Notifications and draws its own
    // top-right toast stack. DND lives in the shared NotificationState singleton,
    // toggled by the bar's DndWidget and the IPC below.
    NotificationDaemon {}

    // The one tooltip surface: hover text from any BarItem / tray icon, rendered
    // below the bar on the hovered item's screen (Services/Tooltip holds the state).
    TooltipWindow {}

    // Keybind bridge: Hyprland binds reach the already-running shell through
    // `marchyo-shell ipc -n call -- shell <fn> [args]` (the wrapper bakes its own
    // -p, so it self-targets the running instance). A single stock IpcHandler, no
    // custom bus, no plugin registry. Panel summons mirror the
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

        // Deferred so the reply reaches the caller before the engine reloads.
        function reload(): string {
            Qt.callLater(() => Quickshell.reload(false));
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

            // The shell's blur anchor: modules/home/hyprland.nix registers blur
            // layer rules for the "marchyo:" namespace prefix when
            // marchyo.theme.appearance.surfaceAlpha < 1.
            WlrLayershell.namespace: "marchyo:bar"

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                // Floating pill: inset from the screen edges. The generator
                // bakes 0 in strip mode (barFloating false), so the strip keeps
                // the full-width edge-to-edge look.
                top: Style.barMarginV
                left: Style.barMarginH
                right: Style.barMarginH
            }
            // Floating pill reserves its own footprint (top inset + height +
            // a matching gap below) so windows tile beneath it instead of
            // being overlapped; the strip keeps Quickshell's default zone
            // (height + margins).
            exclusiveZone: Style.barFloating ? Style.barMarginV * 2 + Style.barHeight : -1
            implicitHeight: Style.barHeight
            color: "transparent"

            // Pill body: the only painted surface, so the corners outside the
            // radius never show bar background. Radius bakes to 0 in strip mode.
            Rectangle {
                id: barBody
                anchors.fill: parent
                radius: Style.barRadius
                color: Qt.alpha(Color.background, Style.surfaceAlpha)
            }

            // Three anchored sections driven by ShellConfig.bar: left and right
            // groups, plus a centered group (the clock by default). Ui/
            // BarSection owns the per-entry Loaders, slot collapse (a hidden
            // widget leaves no gap), and cluster-aware separators.
            Item {
                anchors.fill: parent

                BarSection {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    section: "left"
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                    capId: "marchyo.activeWindow"
                    capFraction: 0.25
                    barWidth: barWin.width
                }

                BarSection {
                    anchors.centerIn: parent
                    section: "center"
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }

                BarSection {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    section: "right"
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }
            }
        }
    }
}
