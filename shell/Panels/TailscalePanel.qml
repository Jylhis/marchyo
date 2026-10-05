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
    title: "Tailscale"

    body: [
        Text {
            Layout.fillWidth: true
            text: Tailscale.running ? "Connected" : "Disconnected"
            color: Tailscale.running ? Color.statusOk : Color.textFaint
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.running && Tailscale.selfName !== ""
            text: Tailscale.selfName + (Tailscale.selfIp !== "" ? "  " + Tailscale.selfIp : "")
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.exitNodeActive
            text: "Exit node: " + Tailscale.exitNodeName
            color: Color.accent
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.running && Tailscale.peers.length > 0
            text: "Peers"
            color: Color.textHeading
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            font.bold: true
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
                    color: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    elide: Text.ElideRight
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: modelData.ip
                    color: Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
            }
        },
        PanelButton {
            Layout.fillWidth: true
            visible: Tailscale.controllable
            text: Tailscale.busy ? "..." : (Tailscale.running ? "Disconnect" : "Connect")
            active: Tailscale.running
            onClicked: Tailscale.setUp(!Tailscale.running)
        },
        Text {
            Layout.fillWidth: true
            visible: Tailscale.lastErrorDetail !== ""
            text: Tailscale.lastErrorDetail
            color: Color.statusErr
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.Wrap
        }
    ]
}
