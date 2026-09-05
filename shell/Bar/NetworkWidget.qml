import QtQuick
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Services

// Connectivity readout. The native Networking binding gives connected/type;
// the active SSID, signal, and IPv4 address come from the shared
// Services/NetworkStatus nmcli poll (one poll for the widget, the network
// panel, and the tooltip — previously widget and panel each ran their own).
// Click opens the in-shell network panel (status + an nmtui escape hatch).
BarItem {
    id: root

    readonly property var activeDevice: NetworkStatus.activeDevice
    readonly property string ssid: NetworkStatus.ssid

    interactive: true
    text: {
        if (!activeDevice)
            return "󰤭";
        if (activeDevice.type === DeviceType.Wired)
            return "󰈀";
        return ssid.length > 0 ? "󰤨 " + NetworkStatus.signalStrength : "󰤨";
    }
    textColor: activeDevice ? Color.text : Color.textFaint
    tooltipText: NetworkStatus.tooltipText

    onClicked: PanelManager.toggle("network")
}
