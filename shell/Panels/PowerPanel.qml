import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Ui
import qs.Commons

// Summoned from BatteryWidget. Battery status from UPower's composite display
// device and a power-profile selector on PowerProfiles — the same services the
// battery and power-profile bar widgets read. "power menu" reaches marchyo's
// session actions (or the launcher when menus are disabled), the action the
// battery widget used to trigger directly.
Panel {
  id: root
  panelId: "power"
  title: "Power"

  readonly property var dev: UPower.displayDevice
  readonly property bool hasBattery: dev && dev.isLaptopBattery && dev.isPresent
  readonly property int pct: dev ? Math.round(dev.percentage) : 0
  readonly property bool charging: dev
    && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)

  function fmtTime(seconds) {
    if (!seconds || seconds <= 0)
      return "";
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return h > 0 ? (h + "h " + m + "m") : (m + "m");
  }

  readonly property string batteryLine: {
    if (!hasBattery)
      return "No battery";
    let s = pct + "%";
    if (dev.state === UPowerDeviceState.FullyCharged) {
      s += " (full)";
    } else if (charging) {
      const t = fmtTime(dev.timeToFull);
      s += t.length > 0 ? (" charging, " + t + " to full") : " charging";
    } else {
      const t = fmtTime(dev.timeToEmpty);
      s += t.length > 0 ? (" (" + t + " left)") : " on battery";
    }
    return s;
  }

  body: [
    Text {
      Layout.fillWidth: true
      text: root.batteryLine
      color: root.hasBattery && root.pct <= 10 ? Color.statusErr : Color.text
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
      elide: Text.ElideRight
    },

    Text {
      Layout.fillWidth: true
      text: "Power profile"
      color: Color.textMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSizeSmall
    },

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing

      PanelButton {
        Layout.fillWidth: true
        text: "eco"
        active: PowerProfiles.profile === PowerProfile.PowerSaver
        onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
      }

      PanelButton {
        Layout.fillWidth: true
        text: "bal"
        active: PowerProfiles.profile === PowerProfile.Balanced
        onClicked: PowerProfiles.profile = PowerProfile.Balanced
      }

      PanelButton {
        Layout.fillWidth: true
        visible: PowerProfiles.hasPerformanceProfile
        text: "perf"
        active: PowerProfiles.profile === PowerProfile.Performance
        onClicked: PowerProfiles.profile = PowerProfile.Performance
      }
    },

    PanelButton {
      Layout.fillWidth: true
      text: "power menu"
      onClicked: Style.menusEnabled
        ? Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.terminal", "-e", Config.marchyo, "menu", "power" ])
        : Quickshell.execDetached([ Config.vicinae, "toggle" ])
    }
  ]
}
