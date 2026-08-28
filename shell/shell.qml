import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.Commons
import qs.Bar
import qs.Osd
import qs.Panels
import qs.Services

// Phase 1: a Jylhis-themed top bar at waybar parity, built as a simple monolith
// — shell.qml composes reusable widgets from qs.Bar (backed by qs.Ui primitives
// and the qs.Commons Color/Style singletons). Phase 2 adds surfaces alongside it
// (starting with the OSD) as plain in-process components — no plugin registry or
// manifest system; native Quickshell service bindings and IpcHandler suffice.
ShellRoot {
  id: shell

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
          WorkspacesWidget {}
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
