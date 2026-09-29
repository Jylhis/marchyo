import qs.Ui
import qs.Services

// Live clock: left-click toggles compact/long format, matching waybar's
// clock format / format-alt pair.
//
// A pure view over Services/Clock: the SystemClock and the format toggle are
// seat-global, so every monitor's bar shows the same thing and a click on one
// bar switches them all.
BarItem {
    id: root

    interactive: true
    text: Clock.barText
    onClicked: Clock.toggleFormat()
}
