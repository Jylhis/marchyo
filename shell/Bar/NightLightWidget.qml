import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Night-light toggle: a pure view over Services/Nightlight, which owns the one
// temperature probe/toggle pair for the seat (the widget is instantiated once
// per monitor). Ported from omarchy's NightLight indicator; marchyo previously
// exposed hyprsunset only at the compositor/CLI level.
BarItem {
    id: root

    interactive: true
    text: "󰔎"
    textColor: Nightlight.enabled ? Color.accent : Color.textMuted
    tooltipText: Nightlight.enabled ? "Night light on (warm)" : "Night light off"

    onClicked: Nightlight.toggle()
}
