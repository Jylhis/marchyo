import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Caffeine (keep-awake) indicator: a pure view over Services/Caffeine, which owns
// the one probe/toggle pair for the seat (the widget is instantiated once per
// monitor).
BarItem {
    id: root

    interactive: true
    compact: true
    text: Caffeine.active ? "󰅶" : "󰾪"
    textColor: Caffeine.active ? Color.accent : Color.textMuted
    tooltipText: Caffeine.manual ? "Caffeine on — screen stays awake" : Caffeine.autoActive ? "Caffeine auto: " + Caffeine.autoPlayer : "Caffeine off"

    onClicked: Caffeine.toggle()
}
