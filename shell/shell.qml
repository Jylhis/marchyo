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
import qs.Notifications
import qs.Services

// Phase 1: a Jylhis-themed top bar at waybar parity, built as a simple monolith
// — shell.qml composes reusable widgets from qs.Bar (backed by qs.Ui primitives
// and the qs.Commons Color/Style singletons). Phase 2 adds surfaces alongside it
// (starting with the OSD) as plain in-process components — no plugin registry or
// manifest system; native Quickshell service bindings and IpcHandler suffice.
ShellRoot {
    id: shell

    // Bar visibility, toggled over IPC (SUPER+SHIFT+SPACE). Replaces waybar's
    // SIGUSR1 show/hide; one property drives every per-screen bar below.
    property bool barVisible: true

    // On-screen display for volume/brightness/mic-mute (replaces SwayOSD). Reacts
    // natively to Pipewire and the backlight sysfs node — no external poke.
    Osd {
        id: osd
    }

    // Summonable panels: toggled in-process from their bar widgets via the shared
    // PanelManager (mutually exclusive). Each is a layer-shell overlay that only
    // materialises a surface while open.
    AudioPanel {}
    NetworkPanel {}
    PowerPanel {}
    MonitorPanel {}

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

        function ping(): string {
            return "ok";
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shell.barVisible

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Style.barHeight
            color: Color.background

            // Three anchored sections: left and right groups, an absolutely-centered
            // clock. Simpler and more robust than fill-width spacers for centering.
            Item {
                anchors.fill: parent

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    SessionWidget {}
                    WorkspacesWidget {
                        screenName: modelData.name
                    }
                }

                ClockWidget {
                    anchors.centerIn: parent
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    TrayWidget {}
                    DictationWidget {}
                    CaffeineWidget {}
                    DndWidget {}
                    KeyboardLayoutWidget {}
                    BluetoothWidget {}
                    NetworkWidget {}
                    AudioWidget {}
                    CpuWidget {}
                    PowerProfileWidget {}
                    BatteryWidget {}
                }
            }
        }
    }
}
