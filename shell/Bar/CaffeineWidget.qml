import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Caffeine (keep-awake) indicator: a pure view over Services/Caffeine, which owns
// the one probe/toggle pair for the seat (the widget itself is instantiated once
// per monitor). Mirrors waybar's custom/caffeine: "on" when the tagged
// `marchyo-caffeine-inhibit` systemd-inhibit process is present.
BarItem {
    id: root

    interactive: true
    text: Caffeine.active ? "󰅶" : "󰾪"
    textColor: Caffeine.active ? Color.accent : Color.textMuted
    tooltipText: Caffeine.active ? "Caffeine on — screen stays awake" : "Caffeine off"

    onClicked: Caffeine.toggle()
}
