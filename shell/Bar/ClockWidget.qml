import qs.Ui
import qs.Commons
import qs.Services

// Live clock: left-click toggles compact/long format, matching waybar's
// clock format / format-alt pair; right-click toggles live seconds.
//
// A pure view over Services/Clock: the SystemClock and the format toggle are
// seat-global, so every monitor's bar shows the same thing and a click on one
// bar switches them all.
BarItem {
    id: root

    interactive: true
    text: Clock.barText
    tooltipText: I18n.t(Clock.showSeconds ? "clock.hintSecondsOff" : "clock.hintSecondsOn")
    onClicked: Clock.toggleFormat()
    onRightClicked: Clock.toggleSeconds()
}
