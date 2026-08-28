import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Services

// Connectivity readout. The native Networking binding gives connected/type; the
// active SSID and signal (which it does not expose) come from an `nmcli` poll while
// on Wi-Fi, matching waybar's "{essid} {signal}%". Click opens the in-shell network
// panel (status + an nmtui escape hatch).
BarItem {
  id: root

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

  interactive: true
  text: {
    if (!activeDevice)
      return "offline";
    if (activeDevice.type === DeviceType.Wired)
      return "eth";
    return ssid.length > 0 ? ssid + " " + signalStrength + "%" : "wifi";
  }
  textColor: activeDevice ? Color.text : Color.textFaint

  // `nmcli -t` yields "active:ssid:signal" lines; the active connection starts "yes:".
  Process {
    id: wifiProbe
    command: [ Config.nmcli, "-t", "-f", "active,ssid,signal", "dev", "wifi" ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.ssid = "";
        root.signalStrength = -1;
        const lines = text.split("\n");
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
    running: root.wifi
    repeat: true
    triggeredOnStart: true
    onTriggered: wifiProbe.running = true
  }

  onClicked: PanelManager.toggle("network")
}
