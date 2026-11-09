import QtQuick
import Quickshell
import Quickshell.Hyprland
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
import qs.Overview
import qs.Polkit
import qs.Services
import qs.Plugins
// omarchy plugin compat host API (shell/compat). Namespaced so its BarWidget /
// Panel / Style / CompatColor do not collide with marchyo's own qs.Ui / qs.Commons.
import qs.compat.Ui as Plugin
import "Commons/ShellSocket.js" as ShellSocket
import "Commons/Appearance.js" as Appearance

// A Jylhis-themed top bar plus the shell surfaces (OSD, panels, lock,
// notifications, launcher), composed from qs.Bar widgets backed by qs.Ui
// primitives and the qs.Commons singletons. The bar layout is data-driven from
// Commons/ShellConfig (a generated, read-only ~/.config/marchyo/shell.json;
// the default reproduces the historical static order). Widget ids resolve to
// first-party Components in `barComponents` below, or to plugin bar-widgets via
// Commons/PluginIndex — the build-time Option A plugin model (Nix-declared,
// store-baked; no runtime discovery). Runtime actions live in one function
// table (`actions` below), reached through the IpcHandler, the unix socket and
// the Hyprland global shortcuts. See shell/README.md.
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
            "marchyo.agents": cAgents,
            "marchyo.remoteSession": cRemoteSession,
            "marchyo.update": cUpdate,
            "marchyo.disk": cDisk,
            "marchyo.health": cHealth,
            "marchyo.tray": cTray,
            "marchyo.media": cMedia,
            "marchyo.dictation": cDictation,
            "marchyo.caffeine": cCaffeine,
            "marchyo.theme": cTheme,
            "marchyo.dnd": cDnd,
            "marchyo.keyboardLayout": cKeyboardLayout,
            "marchyo.bluetooth": cBluetooth,
            "marchyo.network": cNetwork,
            "marchyo.camera": cCamera,
            "marchyo.mic": cMic,
            "marchyo.lockKeys": cLockKeys,
            "marchyo.audio": cAudio,
            "marchyo.cpu": cCpu,
            "marchyo.powerProfile": cPowerProfile,
            "marchyo.peripherals": cPeripherals,
            "marchyo.battery": cBattery,
            "marchyo.controlCenter": cControlCenter
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
        id: cAgents
        AgentsWidget {}
    }
    Component {
        id: cRemoteSession
        RemoteSessionWidget {}
    }
    Component {
        id: cUpdate
        UpdateWidget {}
    }
    Component {
        id: cDisk
        DiskWidget {}
    }
    Component {
        id: cHealth
        HealthWidget {}
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
        id: cCamera
        CameraWidget {}
    }
    Component {
        id: cMic
        MicWidget {}
    }
    Component {
        id: cLockKeys
        LockKeysWidget {}
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
    Component {
        id: cControlCenter
        ControlCenterWidget {}
    }

    // Per-widget host facade handed to an omarchy-compat plugin bar widget as
    // its `bar`. Scalars mirror marchyo's bar (colors, font, geometry); shared
    // popout state and click-target registry delegate to Services/PluginPopout;
    // operations route to marchyo services. Created per plugin widget in
    // applyWidget() so `pluginId`/`moduleName` carry that widget's id.
    Component {
        id: cPluginBar
        Plugin.PluginBarApi {
            foreground: Colors.text
            barForeground: Colors.text
            background: Colors.background
            urgent: Colors.statusErr
            fontFamily: Style.fontFamily
            position: Style.barPosition
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

    // Registers a plugin bar widget with the plugin host for as long as the
    // widget lives, so summon/hide/toggle by id reach its open()/close().
    Component {
        id: cWidgetReg
        QtObject {
            property string pluginId: ""
            property var widget: null
            Component.onCompleted: PluginHost.registerBarWidget(pluginId, widget)
            Component.onDestruction: PluginHost.unregisterBarWidget(pluginId, widget)
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
                    "moduleName": entry.id,
                    "shell": PluginHost.shellFor(entry.id)
                });
            cWidgetReg.createObject(item, {
                "pluginId": entry.id,
                "widget": item
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
    DisplayPanel {}
    WeatherPanel {}
    AgentsPanel {}
    ElsewhenPanel {}
    TailscalePanel {}
    WifiQrPanel {}
    BluetoothPanel {}
    SpeedtestPanel {}
    DropboxPanel {}
    GalleryPanel {}
    WhatsNewPanel {}
    SetupPanel {}
    ImagePicker {
        kind: "themes"
    }
    ImagePicker {
        kind: "backgrounds"
    }
    NotificationCenter {}
    // Quick settings over the Services/QuickToggles model; opens the panels
    // above as detail pages.
    ControlCenter {}

    // Launcher: apps / emoji / clipboard surface, summoned over IPC by the
    // Super+R / Super+period / Super+Ctrl+V binds (see Keybind summons).
    // Not created once plugins replace every launcher role.
    LazyLoader {
        active: Launcher.nativeWindow
        LauncherWindow {}
    }

    // Panel, menu, overlay, service and bar plugins (Commons/PluginIndex).
    PluginLayer {}
    Loader {
        active: PluginIndex.replacementFor("launcher") === "omarchy.menu"
        sourceComponent: Component {
            OmarchyMenuFeed {}
        }
    }
    Loader {
        active: PluginIndex.pluginById("omarchy.clipboard") !== null
        sourceComponent: Component {
            OmarchyClipboardImages {}
        }
    }
    Binding {
        target: PluginHost
        property: "barHidden"
        value: !shell.barVisible
    }

    // Daemon plugins (Commons/PluginIndex): one instance each, owned by the
    // shell root for its lifetime, the plugin analogue of a Services/
    // singleton. A plugin that fails to load is logged and skipped.
    property var pluginDaemons: []
    Component.onCompleted: {
        RuntimeStyle.start();
        Motion.start();
        Dev.start();
        const out = [];
        const entries = PluginIndex.daemonComponents();
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.component.status !== Component.Ready) {
                console.warn(`daemon plugin ${e.id}: ${e.component.errorString()}`);
                continue;
            }
            const obj = e.component.createObject(shell);
            if (obj === null) {
                console.warn(`daemon plugin ${e.id}: could not be created`);
                continue;
            }
            out.push(obj);
        }
        shell.pluginDaemons = out;
    }

    // Window overview: per-monitor workspace grid with live window previews
    // and search, summoned over IPC (Services/Overview holds the state).
    OverviewLayer {}

    // Notifications: owns org.freedesktop.Notifications and draws its own
    // top-right toast stack. DND lives in the shared NotificationState singleton,
    // toggled by the bar's DndWidget and the IPC below.
    NotificationDaemon {}

    // Polkit agent dialog: Services/Polkit registers the session's
    // authentication agent; this draws its centered password prompt.
    // Not created while a plugin replaces "polkit".
    LazyLoader {
        active: PluginIndex.replacementFor("polkit") === ""
        PolkitDialog {}
    }

    // The one tooltip surface: hover text from any BarItem / tray icon, rendered
    // below the bar on the hovered item's screen (Services/Tooltip holds the state).
    TooltipWindow {}

    // The one function table behind every runtime action. The IpcHandler, the
    // unix socket and the Hyprland global shortcuts below all dispatch here.
    // Arguments arrive as strings, and a function's arity is its argument count
    // (ShellSocket.call rejects a mismatch). Panel summons mirror the
    // in-process bar-widget clicks; the OSD poke is a fallback for the
    // brightness case the native watcher cannot cover on some hosts.
    readonly property var actions: ({
            togglePanel: id => {
                PanelManager.toggle(id);
                return "ok";
            },
            openPanel: id => {
                PanelManager.open(id);
                return "ok";
            },
            closePanel: id => {
                if (PanelManager.openId === id)
                    PanelManager.close();
                return "ok";
            },
            closePanels: () => {
                PanelManager.close();
                return "ok";
            },
            openGallery: section => {
                Gallery.section = section;
                PanelManager.open("gallery");
                return "ok";
            },
            toggleDnd: () => {
                NotificationState.toggleDnd();
                return NotificationState.dnd ? "on" : "off";
            },
            setDnd: on => {
                NotificationState.setDnd(shell.truthy(on));
                return NotificationState.dnd ? "on" : "off";
            },
            dndState: () => NotificationState.dnd ? "on" : "off",
            clearNotifications: () => {
                NotificationState.clearAll();
                return "ok";
            },
            dismissLast: () => {
                NotificationState.dismissLast();
                return "ok";
            },
            actNewest: () => NotificationState.actNewest(),
            dismissOne: () => NotificationState.dismissOne(),
            silence: () => {
                NotificationState.toggleDnd();
                return NotificationState.dnd ? "on" : "off";
            },
            notifyKeyboard: () => {
                NotificationState.startKeyboard();
                return NotificationState.kbActive ? "on" : "off";
            },
            toggleNotifications: () => {
                PanelManager.toggle("notifications");
                return "ok";
            },
            clearHistory: () => {
                NotificationState.clearHistory();
                return "ok";
            },
            toggleBar: () => {
                shell.barVisible = !shell.barVisible;
                return shell.barVisible ? "on" : "off";
            },
            setBar: on => {
                shell.barVisible = shell.truthy(on);
                return shell.barVisible ? "on" : "off";
            },
            barState: () => shell.barVisible ? "on" : "off",
            osdShow: (label, percent, hasBar) => {
                osd.show(label, parseInt(percent) || 0, hasBar !== "false");
                return "ok";
            },
            lock: () => {
                Lock.lock();
                return "locked";
            },
            lockState: () => Lock.locked ? "locked" : "unlocked",
            toggleLauncher: mode => Launcher.toggle(mode) ? "on" : "off",
            openLauncher: mode => {
                Launcher.openAs(mode);
                return "on";
            },
            openMenu: route => {
                Launcher.openMenu(route);
                return "on";
            },
            toggleMenu: route => Launcher.toggleMenu(route) ? "on" : "off",
            menuRequest: path => {
                Launcher.openDmenu(path);
                return "on";
            },
            closeLauncher: () => {
                Launcher.close();
                return "ok";
            },
            toggleOverview: () => {
                Overview.toggle();
                return Overview.open ? "on" : "off";
            },
            openOverview: () => {
                Overview.openOverview();
                return "on";
            },
            closeOverview: () => {
                Overview.close();
                return "off";
            },
            refreshLockKeys: () => {
                LockKeys.refresh();
                return "ok";
            },
            caffeineChanged: on => {
                Caffeine.setManual(shell.truthy(on));
                return Caffeine.manual ? "on" : "off";
            },
            nightlightChanged: on => {
                Nightlight.setEnabled(shell.truthy(on));
                return Nightlight.enabled ? "on" : "off";
            },
            summonPlugin: (id, payload) => PluginHost.summon(id, payload) ? "ok" : "unknown",
            hidePlugin: id => PluginHost.hide(id) ? "ok" : "unknown",
            togglePlugin: (id, payload) => PluginHost.toggle(id, payload) ? "ok" : "unknown",
            callPlugin: (id, method, arg) => PluginHost.call(id, method, arg),
            togglePanelAt: (section, index) => PluginHost.togglePanelAt(section, index),
            rescanPlugins: () => PluginHost.rescan(),
            ping: () => "ok",
            // Deferred so the reply reaches the caller before the engine reloads.
            reload: () => {
                Qt.callLater(() => Quickshell.reload(false));
                return "ok";
            }
        })

    function truthy(on: string): bool {
        return on === "true" || on === "on" || on === "1";
    }

    // `marchyo-shell ipc -n call -- shell <fn> [args]` (the wrapper bakes its
    // own -p, so it self-targets the running instance). Each function forwards
    // to the table above; tests/shell/contracts-test.sh keeps the two lists equal.
    IpcHandler {
        target: "shell"

        function togglePanel(id: string): string {
            return shell.actions.togglePanel(id);
        }

        function openPanel(id: string): string {
            return shell.actions.openPanel(id);
        }

        function closePanel(id: string): string {
            return shell.actions.closePanel(id);
        }

        function closePanels(): string {
            return shell.actions.closePanels();
        }

        function openGallery(section: string): string {
            return shell.actions.openGallery(section);
        }

        function toggleDnd(): string {
            return shell.actions.toggleDnd();
        }

        function setDnd(on: string): string {
            return shell.actions.setDnd(on);
        }

        function dndState(): string {
            return shell.actions.dndState();
        }

        function clearNotifications(): string {
            return shell.actions.clearNotifications();
        }

        function dismissLast(): string {
            return shell.actions.dismissLast();
        }

        function actNewest(): string {
            return shell.actions.actNewest();
        }

        function dismissOne(): string {
            return shell.actions.dismissOne();
        }

        function silence(): string {
            return shell.actions.silence();
        }

        function notifyKeyboard(): string {
            return shell.actions.notifyKeyboard();
        }

        function toggleNotifications(): string {
            return shell.actions.toggleNotifications();
        }

        function clearHistory(): string {
            return shell.actions.clearHistory();
        }

        function toggleBar(): string {
            return shell.actions.toggleBar();
        }

        function setBar(on: string): string {
            return shell.actions.setBar(on);
        }

        function barState(): string {
            return shell.actions.barState();
        }

        function osdShow(label: string, percent: string, hasBar: string): string {
            return shell.actions.osdShow(label, percent, hasBar);
        }

        function lock(): string {
            return shell.actions.lock();
        }

        function lockState(): string {
            return shell.actions.lockState();
        }

        function toggleLauncher(mode: string): string {
            return shell.actions.toggleLauncher(mode);
        }

        function openLauncher(mode: string): string {
            return shell.actions.openLauncher(mode);
        }

        function openMenu(route: string): string {
            return shell.actions.openMenu(route);
        }

        function toggleMenu(route: string): string {
            return shell.actions.toggleMenu(route);
        }

        function menuRequest(path: string): string {
            return shell.actions.menuRequest(path);
        }

        function closeLauncher(): string {
            return shell.actions.closeLauncher();
        }

        function toggleOverview(): string {
            return shell.actions.toggleOverview();
        }

        function openOverview(): string {
            return shell.actions.openOverview();
        }

        function closeOverview(): string {
            return shell.actions.closeOverview();
        }

        function refreshLockKeys(): string {
            return shell.actions.refreshLockKeys();
        }

        function caffeineChanged(on: string): string {
            return shell.actions.caffeineChanged(on);
        }

        function nightlightChanged(on: string): string {
            return shell.actions.nightlightChanged(on);
        }

        function summonPlugin(id: string, payload: string): string {
            return shell.actions.summonPlugin(id, payload);
        }

        function hidePlugin(id: string): string {
            return shell.actions.hidePlugin(id);
        }

        function togglePlugin(id: string, payload: string): string {
            return shell.actions.togglePlugin(id, payload);
        }

        function callPlugin(id: string, method: string, arg: string): string {
            return shell.actions.callPlugin(id, method, arg);
        }

        function togglePanelAt(section: string, index: string): string {
            return shell.actions.togglePanelAt(section, index);
        }

        function rescanPlugins(): string {
            return shell.actions.rescanPlugins();
        }

        function ping(): string {
            return shell.actions.ping();
        }

        function reload(): string {
            return shell.actions.reload();
        }
    }

    // Hyprland global shortcuts `marchyo:<name>`, one per shell/shortcuts.json
    // entry (lib/hyprland-lua.nix's `global` reads the same file), so a bind
    // reaches the shell without spawning a process.
    FileView {
        id: shortcutsFile
        path: Quickshell.shellDir + "/shortcuts.json"
        blockLoading: true
    }

    Variants {
        model: ShellSocket.parseShortcuts(shortcutsFile.text())

        GlobalShortcut {
            required property var modelData
            appid: "marchyo"
            name: modelData.name
            description: modelData.description
            onPressed: ShellSocket.call(shell.actions, modelData.call, modelData.args)
        }
    }

    // The CLI's fast path (core/src/shell-ipc.ts): one request per connection,
    // framed by Commons/ShellSocket.js. The name hashes this shell's directory
    // and display, like qs ipc's instance match, so the CLI derives the same
    // path. Only the owning user can connect: the socket sits in the 0700
    // XDG_RUNTIME_DIR and is chmodded 0600 once it listens.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string socketPath: shell.runtimeDir === "" ? "" : shell.runtimeDir + "/" + ShellSocket.socketName(Quickshell.shellDir, Quickshell.env("WAYLAND_DISPLAY") || "", s => Qt.md5(s))

    SocketServer {
        active: shell.socketPath !== ""
        path: shell.socketPath
        onActiveStatusChanged: {
            if (active)
                socketMode.running = true;
        }

        // An empty split marker hands over raw chunks, so ShellSocket.feed
        // enforces the size cap before the request is complete.
        handler: Socket {
            id: connection
            property string pending: ""
            property bool answered: false

            function answer(text: string): void {
                if (connection.answered)
                    return;
                connection.answered = true;
                connection.pending = "";
                connection.write(text);
                connection.flush();
                connection.connected = false;
            }

            parser: SplitParser {
                splitMarker: ""
                onRead: data => {
                    const step = ShellSocket.feed(connection.pending, data);
                    if (!step.done)
                        connection.pending = step.buffer;
                    else if (step.error)
                        connection.answer(ShellSocket.reply("ERR", step.error));
                    else
                        connection.answer(ShellSocket.handle(shell.actions, step.record));
                }
            }

            property Timer idle: Timer {
                interval: ShellSocket.IDLE_TIMEOUT_MS
                running: !connection.answered
                onTriggered: connection.answer(ShellSocket.reply("ERR", "request timed out"))
            }
        }
    }

    Process {
        id: socketMode
        command: [Config.chmod, "0600", shell.socketPath]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWin
            required property var modelData
            readonly property string screenName: modelData.name
            screen: modelData
            visible: shell.barVisible && !PluginHost.customBar

            // The shell's blur anchor: modules/home/hyprland.nix registers blur
            // layer rules for the "marchyo:" namespace prefix when
            // marchyo.theme.appearance.surfaceAlpha < 1.
            WlrLayershell.namespace: "marchyo:bar"

            anchors {
                top: !Style.barBottom
                bottom: Style.barBottom
                left: true
                right: true
            }
            margins {
                // Floating pill: inset from the screen edges. The generator
                // bakes 0 in strip mode (barFloating false), so the strip keeps
                // the full-width edge-to-edge look.
                top: Style.barBottom ? 0 : Style.barMarginV
                bottom: Style.barBottom ? Style.barMarginV : 0
                left: Style.barMarginH
                right: Style.barMarginH
            }
            // Always explicit: assigning exclusiveZone switches exclusionMode to
            // Normal, where -1 reserves nothing and windows tile under the bar.
            // The compositor adds the top margin itself, so the pill gets a gap
            // below matching its top inset; the strip (margin 0) reserves
            // exactly its height.
            exclusiveZone: Style.barHeight + Style.barMarginV
            implicitHeight: Style.barHeight
            color: "transparent"

            // Pill body: the only painted surface, so the corners outside the
            // radius never show bar background. Radius bakes to 0 in strip mode.
            Rectangle {
                id: barBody
                anchors.fill: parent
                radius: Style.barRadius
                color: Qt.alpha(Colors.background, Style.barAlpha)
            }

            // Double-clicking empty bar space steps the bar background
            // (opaque, glassy, clear). Widgets and sections sit above this
            // area, so only the gaps between them reach it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onDoubleClicked: Quickshell.execDetached([Config.marchyo, "theme", "bar-background", Appearance.nextBarBackground(Style.barBackground)])
            }

            // Five sections driven by ShellConfig.barFor() for this output:
            // left and right groups, and a centre group split around its
            // anchor. `center` (the clock by default) stays at the exact
            // middle; centerBegin grows leftwards from it and centerEnd
            // rightwards, so a widget that appears or resizes never moves the
            // anchor. Ui/BarSection owns the per-entry Loaders, slot collapse
            // (a hidden widget leaves no gap), and cluster-aware separators.
            Item {
                anchors.fill: parent
                property bool indicatorReveal: false

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            indicatorHide.stop();
                            parent.indicatorReveal = true;
                        } else {
                            indicatorHide.restart();
                        }
                    }
                }
                Timer {
                    id: indicatorHide
                    interval: 120
                    onTriggered: parent.indicatorReveal = false
                }

                BarSection {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    section: "left"
                    screenName: barWin.screenName
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                    capId: "marchyo.activeWindow"
                    capFraction: 0.25
                    barWidth: barWin.width
                }

                BarSection {
                    id: centerSection
                    anchors.centerIn: parent
                    section: "center"
                    screenName: barWin.screenName
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }

                BarSection {
                    anchors.right: centerSection.left
                    anchors.verticalCenter: parent.verticalCenter
                    section: "centerBegin"
                    screenName: barWin.screenName
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }

                BarSection {
                    anchors.left: centerSection.right
                    anchors.verticalCenter: parent.verticalCenter
                    section: "centerEnd"
                    screenName: barWin.screenName
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }

                BarSection {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    section: "right"
                    screenName: barWin.screenName
                    resolve: shell.componentFor
                    configure: (item, entry) => shell.applyWidget(item, entry, barWin.screenName)
                }
            }
        }
    }
}
