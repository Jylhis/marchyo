import qs.Ui
import qs.Services

// Live clock. Left-click toggles between the compact form ("Sat 22 Aug · 14:30")
// and the long form with ISO week ("22 August W34 2025"), matching waybar's
// clock format / format-alt pair.
//
// A pure view over Services/Clock: the SystemClock and the format toggle are
// seat-global, so every monitor's bar shows the same thing and a click on one
// bar switches them all. Compare Bar/BatteryWidget over Services/Power.
BarItem {
    id: root

    interactive: true
    text: Clock.barText
    onClicked: Clock.toggleFormat()
}
