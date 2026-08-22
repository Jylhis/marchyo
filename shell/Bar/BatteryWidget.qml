import Quickshell.Services.UPower
import qs.Ui
import qs.Commons

// Battery readout via UPower's composite display device. Hidden on desktops
// (no laptop battery). Warning/critical thresholds match waybar (20% / 10%).
BarItem {
  readonly property var dev: UPower.displayDevice
  readonly property int pct: dev ? Math.round(dev.percentage) : 0
  readonly property bool charging: dev
    && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)

  visible: dev && dev.isLaptopBattery && dev.isPresent
  text: (charging ? "chg " : "bat ") + pct + "%"
  textColor: pct <= 10 ? Color.statusErr : (pct <= 20 ? Color.statusWarn : Color.text)
}
