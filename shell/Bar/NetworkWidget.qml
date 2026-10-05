import QtQuick
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Services

// Connectivity readout over Services/NetworkStatus (native Networking device,
// SSID, and signal; IPv4 address for the tooltip), shared by the widget, the
// network panel, and the tooltip.
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

    onClicked: PanelManager.toggle("network", root)
}
