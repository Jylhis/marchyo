import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// Summoned from WeatherWidget. Current conditions plus up to a 3-day forecast,
// all from the shared Services/Weather poll (the same wttr.in fetch the bar
// widget reads). Ported from omarchy's weather panel, trimmed to the forecast
// view (no location picker / unit toggle).
Panel {
    id: root
    panelId: "weather"
    title: "Weather"

    body: [
        Text {
            Layout.fillWidth: true
            text: Weather.available ? Weather.icon + "  " + Weather.tempC + "°C" : "Unavailable"
            color: Color.textHeading
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        },
        Text {
            Layout.fillWidth: true
            visible: Weather.description !== ""
            text: Weather.description
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
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
                    color: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
                Text {
                    text: modelData.icon
                    color: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: modelData.hi + "° / " + modelData.lo + "°"
                    color: Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
            }
        }
    ]
}
