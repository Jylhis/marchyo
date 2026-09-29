import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Services

// Connection status from the native Networking binding, enriched with SSID, signal,
// and IP from the shared Services/NetworkStatus poll. nmtui opens the full text UI.
Panel {
    id: root
    panelId: "network"
    title: "Network"

    readonly property var activeDevice: NetworkStatus.activeDevice
    readonly property bool wifi: NetworkStatus.wifi

    readonly property string statusText: {
        if (!activeDevice)
            return "Offline";
        if (activeDevice.type === DeviceType.Wired)
            return "Wired (connected)";
        return "Wi-Fi (connected)";
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
            visible: root.wifi && NetworkStatus.ssid.length > 0
            text: NetworkStatus.ssid + "  " + NetworkStatus.signalStrength + "%"
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: NetworkStatus.ipAddress.length > 0
            text: NetworkStatus.ipAddress + "  " + NetworkStatus.ifName
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        PanelButton {
            Layout.fillWidth: true
            visible: root.wifi && NetworkStatus.ssid.length > 0
            text: "Share (QR)"
            onClicked: PanelManager.open("wifiqr", root)
        },
        PanelButton {
            Layout.fillWidth: true
            text: "nmtui"
            onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.nmtui", "-e", Config.nmtui])
        }
    ]
}
