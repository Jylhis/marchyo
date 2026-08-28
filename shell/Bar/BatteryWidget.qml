import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services

// Battery readout via UPower's composite display device, shared with the power
// panel through Services/Power. Hidden on desktops (no laptop battery). Bar text
// keeps waybar's bat/chg/pwr/bat-full forms; warning/critical thresholds match
// waybar (20% / 10%). Click opens the in-shell power panel (battery detail +
// profile selector, with a power-menu escape hatch).
BarItem {
    readonly property var dev: Power.dev
    readonly property int pct: Power.pct

    visible: Power.hasBattery
    interactive: true
    text: Power.barText
    textColor: pct <= 10 ? Color.statusErr : (pct <= 20 ? Color.statusWarn : Color.text)
    tooltipText: Power.tooltipText

    onClicked: PanelManager.toggle("power")
}
