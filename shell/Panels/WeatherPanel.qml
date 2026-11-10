import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// Current conditions plus up to a 3-day forecast from the shared Services/Weather
// (wttr.in) poll.
Panel {
    id: root
    panelId: "weather"
    title: I18n.t("weather.title")

    body: [
        Text {
            Layout.fillWidth: true
            text: Weather.available ? Weather.icon + "  " + Weather.tempC + "°C" : I18n.t("weather.unavailable")
            color: Colors.textHeading
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: Weather.description !== ""
            text: Weather.description
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        PanelSectionHeader {
            visible: Weather.forecast.length > 0
            text: I18n.t("weather.forecast")
        },
        Repeater {
            model: Weather.forecast

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.spacing

                Text {
                    Layout.preferredWidth: Style.panelWidth * 0.25
                    text: modelData.day
                    color: Colors.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
                Text {
                    text: modelData.icon
                    color: Colors.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: modelData.hi + "° / " + modelData.lo + "°"
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
            }
        }
    ]
}
