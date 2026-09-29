import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// Wi-Fi QR share overlay, opened from the Network panel's "Share (QR)" button.
// Regenerates the QR each time it opens (the network may have changed). The QR
// is a UTF8 half-block text grid from qrencode; rendering it needs a monospace
// font (Style.fontFamily is BlexMono) and a tight line height so the half-block
// rows stack into a square, scannable code.
Panel {
    id: root
    panelId: "wifiqr"
    title: "Wi-Fi QR"

    onVisibleChanged: {
        if (visible)
            WifiQr.generate();
    }

    body: [
        Text {
            Layout.fillWidth: true
            visible: WifiQr.ssid !== ""
            text: WifiQr.ssid
            color: Color.textHeading
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            elide: Text.ElideRight
        },
        Text {
            Layout.fillWidth: true
            visible: WifiQr.error !== ""
            text: WifiQr.error
            color: Color.statusErr
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: WifiQr.qrText !== ""
            text: WifiQr.qrText
            color: Color.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            // Half-block rows are two cells tall; collapse the line box so the
            // code renders as a square rather than a tall rectangle.
            lineHeight: 0.5
            lineHeightMode: Text.ProportionalHeight
            textFormat: Text.PlainText
        }
    ]
}
