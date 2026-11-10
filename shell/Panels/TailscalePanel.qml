import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// View over the shared Services/Tailscale poll, with a connect/disconnect
// button when the CLI is baked. No exit-node picker. The daemon accepts up/down
// only from root or the tailnet operator, so a refusal is shown under the button.
Panel {
    id: root
    panelId: "tailscale"
    title: I18n.t("tailscale.title")

    body: [
        Text {
            Layout.fillWidth: true
            text: Tailscale.running ? I18n.t("tailscale.connected") : I18n.t("tailscale.disconnected")
            color: Tailscale.running ? Colors.statusOk : Colors.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.running && Tailscale.selfName !== ""
            text: Tailscale.selfName + (Tailscale.selfIp !== "" ? "  " + Tailscale.selfIp : "")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.exitNodeActive
            text: I18n.t("tailscale.exitNode", Tailscale.exitNodeName)
            color: Colors.accent
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        PanelSectionHeader {
            visible: Tailscale.running && Tailscale.peers.length > 0
            text: I18n.t("tailscale.peers")
        },
        Repeater {
            model: Tailscale.peers

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.spacing

                Text {
                    Layout.preferredWidth: Style.panelWidth * 0.45
                    text: modelData.name
                    color: Colors.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    elide: Text.ElideRight
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: modelData.ip
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
            }
        },
        Toggle {
            Layout.fillWidth: true
            visible: Tailscale.controllable
            label: Tailscale.busy ? "…" : I18n.t("tailscale.title")
            checked: Tailscale.running
            enabled: !Tailscale.busy
            onToggled: value => Tailscale.setUp(value)
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.lastErrorDetail !== ""
            text: Tailscale.lastErrorDetail
            color: Colors.statusErr
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.Wrap
        }
    ]
}
