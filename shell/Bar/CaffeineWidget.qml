import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Caffeine (keep-awake) indicator: a pure view over Services/Caffeine, which owns
// the one probe/toggle pair for the seat (the widget is instantiated once per
// monitor).
BarIndicator {
    id: root

    interactive: true
    compact: true
    indicatorActive: Caffeine.active
    text: Caffeine.active ? "󰅶" : "󰾪"
    textColor: Caffeine.active ? Colors.accent : Colors.textMuted
    tooltipText: Caffeine.manual ? I18n.t("caffeine.tooltipOn") : Caffeine.autoActive ? I18n.t("caffeine.tooltipAuto", Caffeine.autoPlayer) : I18n.t("caffeine.tooltipOff")

    onClicked: Caffeine.toggle()
}
