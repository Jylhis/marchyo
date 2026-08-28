pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons

// Shared network status: the active device from the native Networking binding
// plus the bits it does not expose — the Wi-Fi SSID/signal and the IPv4 address
// — from one nmcli poll shared by the bar widget, the network panel, and the
// bar tooltips. Previously widget and panel each ran their own poll.
QtObject {
    id: root

    // The first connected device from the native Networking service.
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
    property string ipAddress: ""
    property string ifName: ""

    // Tooltip text (waybar parity: "{ipaddr}  {ifname}", plus the SSID on Wi-Fi).
    readonly property string tooltipText: {
        const parts = [];
        if (root.ssid.length > 0)
            parts.push(root.ssid);
        if (root.ipAddress.length > 0)
            parts.push(root.ipAddress);
        if (root.ifName.length > 0)
            parts.push(root.ifName);
        return parts.length > 0 ? parts.join("  ") : "offline";
    }

    // `nmcli -t` yields "active:ssid:signal" lines; the active connection starts "yes:".
    readonly property var wifiProbe: Process {
        id: wifiProbe
        command: [Config.nmcli, "-t", "-f", "active,ssid,signal", "dev", "wifi"]
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

    // Per-device IPv4 + interface name: "device:ip4" for each connected device;
    // we keep the first one that has an address (the device the widget shows).
    readonly property var addrProbe: Process {
        id: addrProbe
        command: [Config.nmcli, "-t", "-f", "DEVICE,STATE,IP4.ADDRESS", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ipAddress = "";
                root.ifName = "";
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    // lines look like "wlan0:connected:192.168.1.10/24" —
                    // disconnected devices have an empty last field.
                    if (parts.length >= 3 && parts[2].length > 0 && parts[1] === "connected") {
                        root.ifName = parts[0];
                        root.ipAddress = parts[2].split("/")[0];
                        break;
                    }
                }
            }
        }
    }

    // One poll drives both probes (cheap, always-on like the other bar bindings,
    // so the tooltip's address is always current even while the panel is closed).
    readonly property var pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiProbe.running = true;
            addrProbe.running = true;
        }
    }
}
