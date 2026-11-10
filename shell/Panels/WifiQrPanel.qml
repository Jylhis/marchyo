import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

Panel {
    id: root
    panelId: "wifiqr"
    title: I18n.t("wifiqr.title")
    property bool reveal: false

    onVisibleChanged: {
        reveal = false;
        if (visible)
            WifiQr.generate();
        else
            WifiQr.cancel();
    }

    component Caption: Text {
        Layout.fillWidth: true
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }

    body: [
        Caption {
            visible: WifiQr.ssid !== ""
            text: WifiQr.ssid
            color: Colors.textHeading
            font.pixelSize: Style.fontSize
        },
        Caption {
            visible: WifiQr.loading
            text: I18n.t("wifiqr.generating")
        },
        Caption {
            visible: WifiQr.error !== ""
            text: WifiQr.error
            color: Colors.statusErr
        },
        Rectangle {
            id: canvas
            Layout.alignment: Qt.AlignHCenter
            readonly property int moduleSize: Math.max(1, Math.min(6, Math.floor((root.cardWidth - Style.panelPad * 4) / Math.max(1, WifiQr.matrix.size))))
            implicitWidth: WifiQr.matrix.size * moduleSize
            implicitHeight: implicitWidth
            visible: WifiQr.matrix.size > 0
            color: "white"
            radius: Style.panelRadius

            Repeater {
                model: WifiQr.matrix.cells
                Rectangle {
                    required property var modelData
                    x: modelData.x * canvas.moduleSize
                    y: modelData.y * canvas.moduleSize
                    width: canvas.moduleSize
                    height: width
                    color: "black"
                }
            }
        },
        Caption {
            visible: WifiQr.matrix.size > 0
            text: I18n.t("wifiqr.scan") + " · " + I18n.t(WifiQr.secured ? "wifiqr.secured" : "wifiqr.open")
            horizontalAlignment: Text.AlignHCenter
        },
        PanelButton {
            Layout.fillWidth: true
            visible: WifiQr.matrix.size > 0 && WifiQr.secured
            text: I18n.t(root.reveal ? "wifiqr.hidePassword" : "wifiqr.showPassword")
            onClicked: root.reveal = !root.reveal
        },
        Caption {
            visible: root.reveal && WifiQr.password !== ""
            text: root.reveal ? WifiQr.password : ""
        }
    ]
}
