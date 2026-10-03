import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services

// Battery readout via UPower's composite display device, shared with the power
// panel through Services/Power. Hidden on desktops (no laptop battery).
BarItem {
    id: root

    readonly property var dev: Power.dev
    readonly property int pct: Power.pct

    shown: Power.hasBattery
    interactive: true
    text: Power.barText
    // Continuous gradient tint instead of discrete thresholds.
    textColor: Power.barColor
    tooltipText: Power.tooltipText

    onClicked: PanelManager.toggle("power", root)
}
