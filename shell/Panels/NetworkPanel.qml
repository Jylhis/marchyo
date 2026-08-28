import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Ui
import qs.Commons

// Summoned from NetworkWidget. Connection status from the native Networking
// binding, enriched (while open, on Wi-Fi) with the active SSID/signal via the
// same nmcli poll the bar widget uses. "nmtui" opens the full text UI for
// connecting, forgetting, and editing profiles.
Panel {
  id: root
  panelId: "network"
  title: "Network"

  readonly property var activeDevice: {
    const devs = Networking.devices ? Networking.devices.values : [];
    for (let i = 0; i < devs.length; i++)
      if (devs[i].connected)
        return devs[i];
    return null;
  }
  readonly property bool wifi: activeDevice && activeDevice.type !== DeviceType.Wired
  property string ssid: ""
  property int signalStrength: -1

  readonly property string statusText: {
    if (!activeDevice)
      return "Offline";
    if (activeDevice.type === DeviceType.Wired)
      return "Wired (connected)";
    return "Wi-Fi (connected)";
  }

  // Poll only while the panel is open and on Wi-Fi. `nmcli -t` yields
  // "active:ssid:signal" lines; the active connection starts "yes:".
  Process {
    id: wifiProbe
    command: [ Config.nmcli, "-t", "-f", "active,ssid,signal", "dev", "wifi" ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.ssid = "";
        root.signalStrength = -1;
        const lines = this.text.split("\n");
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].indexOf("yes:") === 0) {
            const parts = lines[i].split(":");
            root.ssid = parts[1] || "";
            root.signalStrength = parseInt(parts[2]) || 0;
            break;
          }
        }
      }
    }
  }

  Timer {
    interval: 5000
    running: root.visible && root.wifi
    repeat: true
    triggeredOnStart: true
    onTriggered: wifiProbe.running = true
  }

  body: [
    Text {
      Layout.fillWidth: true
      text: root.statusText
      color: root.activeDevice ? Color.text : Color.textFaint
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
    },

    Text {
      Layout.fillWidth: true
      visible: root.wifi && root.ssid.length > 0
      text: root.ssid + "  " + root.signalStrength + "%"
      color: Color.textMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSizeSmall
      elide: Text.ElideRight
    },

    PanelButton {
      Layout.fillWidth: true
      text: "nmtui"
      onClicked: Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.nmtui", "-e", Config.nmtui ])
    }
  ]
}
