import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Speedtest.js" as ST

// Network speed (ping, download, upload) and disk speed (write, read) from
// Services/Speedtest. Each test runs on request; results stay until the next
// run. The network test moves about 125 MB.
Panel {
    id: root
    panelId: "speedtest"
    title: I18n.t("speedtest.title")

    onVisibleChanged: {
        if (!visible)
            Speedtest.stop();
    }

    component Result: RowLayout {
        id: result
        property string label: ""
        property string value: "-"
        property bool active: false
        Layout.fillWidth: true
        spacing: Style.spacing

        Text {
            Layout.fillWidth: true
            text: result.label
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
        Text {
            text: result.active ? "…" : result.value
            color: result.active ? Colors.accent : Colors.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }
    }

    body: [
        PanelSectionHeader {
            text: I18n.t("speedtest.network")
        },
        Result {
            label: I18n.t("speedtest.ping")
            value: ST.formatMs(Speedtest.pingMs)
            active: Speedtest.phase === "ping"
        },
        Result {
            label: I18n.t("speedtest.download")
            value: ST.formatMbps(Speedtest.downMbps)
            active: Speedtest.phase === "down"
        },
        Result {
            label: I18n.t("speedtest.upload")
            value: ST.formatMbps(Speedtest.upMbps)
            active: Speedtest.phase === "up"
        },
        Button {
            Layout.fillWidth: true
            text: Speedtest.running && Speedtest.kind === "network" ? I18n.t("speedtest.stop") : I18n.t("speedtest.runNetwork")
            enabled: !Speedtest.running || Speedtest.kind === "network"
            onClicked: Speedtest.running ? Speedtest.stop() : Speedtest.startNetwork()
        },
        PanelSectionHeader {
            text: I18n.t("speedtest.disk")
        },
        Result {
            label: I18n.t("speedtest.write")
            value: ST.formatMBps(Speedtest.writeMBps)
            active: Speedtest.phase === "write"
        },
        Result {
            label: I18n.t("speedtest.read")
            value: ST.formatMBps(Speedtest.readMBps)
            active: Speedtest.phase === "read"
        },
        Button {
            Layout.fillWidth: true
            text: Speedtest.running && Speedtest.kind === "disk" ? I18n.t("speedtest.stop") : I18n.t("speedtest.runDisk")
            enabled: !Speedtest.running || Speedtest.kind === "disk"
            onClicked: Speedtest.running ? Speedtest.stop() : Speedtest.startDisk()
        },
        Text {
            Layout.fillWidth: true
            visible: Speedtest.error !== ""
            text: "✗ " + I18n.t(Speedtest.error)
            color: Colors.statusErr
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    ]
}
