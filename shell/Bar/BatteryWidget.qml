import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services

// Battery readout via UPower's composite display device. Hidden on desktops
// (no laptop battery). Warning/critical thresholds match waybar (20% / 10%).
// Click opens the in-shell power panel (battery detail + profile selector, with a
// power-menu escape hatch).
BarItem {
    readonly property var dev: UPower.displayDevice
    readonly property int pct: dev ? Math.round(dev.percentage) : 0
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)

    visible: dev && dev.isLaptopBattery && dev.isPresent
    interactive: true
    text: (charging ? "chg " : "bat ") + pct + "%"
    textColor: pct <= 10 ? Color.statusErr : (pct <= 20 ? Color.statusWarn : Color.text)

    onClicked: PanelManager.toggle("power")
}
