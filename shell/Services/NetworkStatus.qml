pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import "../Commons/Format.js" as Format

// Shared network status for the bar widget, the network panel, the Control
// Center, and the tooltips. The native Networking binding supplies the active
// device, its interface name, the connected Wi-Fi network (SSID + signal), and
// the Wi-Fi radio switch. It does not expose IP configuration, so the IPv4
// address comes from a one-shot `nmcli device show <ifname>` that runs only when
// the active device, its state, or the connected network changes (no poll).
QtObject {
    id: root

    readonly property var activeDevice: {
        const devs = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < devs.length; i++)
            if (devs[i].connected)
                return devs[i];
        return null;
    }
    readonly property bool wifi: activeDevice && activeDevice.type !== DeviceType.Wired

    // Wi-Fi radio: whether this host has a Wi-Fi device at all, NetworkManager's
    // software radio switch (writable through setWifiEnabled), and the rfkill
    // hardware switch (read-only; while it is off the radio cannot be enabled).
    readonly property bool wifiAvailable: {
        const devs = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi)
                return true;
        return false;
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    // The Wi-Fi network the active device is associated with. NetworkManager
    // keeps the access-point list current without a scan request, so this needs
    // no scanner.
    readonly property var wifiNetwork: {
        if (!activeDevice || activeDevice.type !== DeviceType.Wifi)
            return null;
        const nets = activeDevice.networks ? activeDevice.networks.values : [];
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected)
                return nets[i];
        return null;
    }
    readonly property string ssid: wifiNetwork ? wifiNetwork.name : ""
    // Percent, -1 = no reading (the native value is 0.0..1.0).
    readonly property int signalStrength: wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) : -1
    readonly property string ifName: activeDevice ? activeDevice.name : ""
    property string ipAddress: ""
    // Latch so a failing address probe is reported once, not on every change.
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

    onIfNameChanged: addrDebounce.restart()
    onSsidChanged: addrDebounce.restart()

    readonly property var deviceWatch: Connections {
        target: root.activeDevice
        ignoreUnknownSignals: true
        function onStateChanged() {
            addrDebounce.restart();
        }
    }

    // Coalesces the change burst of one (re)connect into a single probe.
    readonly property var addrDebounce: Timer {
        id: addrDebounce
        interval: 500
        triggeredOnStart: false
        onTriggered: {
            if (root.ifName.length === 0) {
                root.ipAddress = "";
                return;
            }
            addrProbe.command = [Config.nmcli, "-t", "-f", "GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS", "device", "show", root.ifName];
            addrProbe.running = true;
        }
    }

    // IPv4 of the active device. `device show` (not `device status`, which
    // rejects the IP4.ADDRESS field outright) emits a "key:value" block, parsed
    // by Commons/Format.js.
    readonly property var addrProbe: Process {
        id: addrProbe
        // A bad field name makes nmcli exit 2 and print nothing, which is
        // indistinguishable from "no address" in the bar. Say so once.
        onExited: exitCode => {
            if (exitCode !== 0 && !root.addrProbeFailed) {
                root.addrProbeFailed = true;
                console.warn("NetworkStatus: nmcli device show failed (exit " + exitCode + "); no IPv4 address will be shown");
            }
        }
        stdout: StdioCollector {
            readonly property int maxChars: 16384
            onStreamFinished: root.ipAddress = text.length <= maxChars ? Format.parseDeviceAddress(text).ipAddress : ""
        }
    }

    Component.onCompleted: addrDebounce.restart()
}
