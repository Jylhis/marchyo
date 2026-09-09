pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import "../Commons/Format.js" as Format

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
    // Latch so a failing address probe is reported once, not every poll.
    property bool addrProbeFailed: false

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

    // `nmcli -t` yields "active:ssid:signal" records; the parse lives in
    // Commons/Format.js so the escaping rules (an SSID may contain a literal
    // colon, escaped by nmcli as "\\:") are covered by the headless tests
    // rather than only by a running bar.
    readonly property var wifiProbe: Process {
        id: wifiProbe
        command: [Config.nmcli, "-t", "-f", "active,ssid,signal", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wifi = Format.parseWifi(text);
                root.ssid = wifi.ssid;
                root.signalStrength = wifi.signal;
            }
        }
    }

    // Per-device IPv4 + interface name. `device show` (not `device status`,
    // which rejects the IP4.ADDRESS field outright) emits one blank-line
    // separated "key:value" block per device; parsed by Commons/Format.js.
    readonly property var addrProbe: Process {
        id: addrProbe
        command: [Config.nmcli, "-t", "-f", "GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS", "device", "show"]
        // A bad field name makes nmcli exit 2 and print nothing, which is
        // indistinguishable from "no address" in the bar. Say so once instead
        // of silently polling a failing command for the whole session.
        onExited: exitCode => {
            if (exitCode !== 0 && !root.addrProbeFailed) {
                root.addrProbeFailed = true;
                console.warn("NetworkStatus: nmcli device show failed (exit " + exitCode + "); no IPv4 address will be shown");
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const dev = Format.parseDeviceAddress(text);
                root.ifName = dev.ifName;
                root.ipAddress = dev.ipAddress;
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
