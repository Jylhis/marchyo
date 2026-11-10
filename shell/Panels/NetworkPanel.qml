import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Services

// Connection status and the Wi-Fi radio switch from the native Networking
// binding, enriched with SSID, signal, and IP from the shared
// Services/NetworkStatus poll. nmtui opens the full text UI.
Panel {
    id: root
    panelId: "network"
    title: I18n.t("network.title")

    readonly property var activeDevice: NetworkStatus.activeDevice
    readonly property bool wifi: NetworkStatus.wifi

    readonly property string statusText: {
        if (!activeDevice)
            return I18n.t("network.offline");
        if (activeDevice.type === DeviceType.Wired)
            return I18n.t("network.wired");
        return I18n.t("network.wifiConnected");
    }

    body: [
        Text {
            Layout.fillWidth: true
            text: root.statusText
            color: root.activeDevice ? Colors.text : Colors.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: root.wifi && NetworkStatus.ssid.length > 0
            text: NetworkStatus.ssid + "  " + NetworkStatus.signalStrength + "%"
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: NetworkStatus.ipAddress.length > 0
            text: NetworkStatus.ipAddress + "  " + NetworkStatus.ifName
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: NetworkStatus.restricted
            text: NetworkStatus.connectivity === "Portal" ? I18n.t("network.signInRequired") : I18n.t("network.limited")
            color: Colors.statusWarn
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        PanelButton {
            Layout.fillWidth: true
            visible: NetworkStatus.restricted
            text: I18n.t("network.openPortal")
            onClicked: NetworkStatus.openCaptivePortal()
        },
        PanelButton {
            Layout.fillWidth: true
            visible: root.wifi && NetworkStatus.ssid.length > 0
            text: I18n.t("network.shareQr")
            onClicked: PanelManager.open("wifiqr", root)
        },
        PanelButton {
            Layout.fillWidth: true
            visible: NetworkStatus.wifiAvailable
            text: !NetworkStatus.wifiHardwareEnabled ? I18n.t("network.wifiBlocked") : I18n.t(NetworkStatus.wifiEnabled ? "network.wifiOn" : "network.wifiOff")
            active: NetworkStatus.wifiEnabled
            onClicked: {
                if (NetworkStatus.wifiHardwareEnabled)
                    NetworkStatus.setWifiEnabled(!NetworkStatus.wifiEnabled);
            }
        },
        PanelButton {
            Layout.fillWidth: true
            text: "nmtui"
            onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.nmtui", "-e", Config.nmtui])
        }
    ]
}
