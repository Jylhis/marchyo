import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Weather indicator: a pure view over Services/Weather (current conditions from
// wttr.in, IP-geolocated). Self-hides until the first successful fetch. Ported
// from omarchy's weather bar widget; the forecast panel is a later port.
// Registered but not placed by default — add marchyo.weather to a section to
// show it (which is also what starts the periodic fetch).
BarItem {
    id: root

    interactive: true
    visible: Weather.available
    text: Weather.icon + "  " + Weather.tempC + "°C"
    textColor: Color.text
    tooltipText: Weather.description !== "" ? Weather.description + ", " + Weather.tempC + "°C" : "Weather"

    onClicked: PanelManager.toggle("weather", root)
}
