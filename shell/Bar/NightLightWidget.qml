import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Night-light toggle: a pure view over Services/Nightlight, which owns the one
// temperature probe/toggle pair for the seat (the widget is instantiated once
// per monitor).
BarIndicator {
    id: root

    interactive: true
    compact: true
    indicatorActive: Nightlight.enabled
    text: "󰔎"
    textColor: Nightlight.enabled ? Colors.accent : Colors.textMuted
    tooltipText: I18n.t(Nightlight.enabled ? "nightlight.on" : "nightlight.off")

    onClicked: Nightlight.toggle()
}
