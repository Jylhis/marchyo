pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// Shared UPower derivations for the battery bar widget and the power panel:
// the composite display device plus the resolved percentage / state / rate.
// Also carries the waybar-parity formatting (bat / chg / pwr / bat full and
// the "N% (Nh Nm left)" line) so the widget and the panel cannot drift apart.
QtObject {
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.isLaptopBattery && dev.isPresent
    readonly property int pct: dev ? Math.round(dev.percentage) : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev && dev.state === UPowerDeviceState.FullyCharged
    // UPower energy-rate in W; positive while charging, negative while discharging.
    readonly property real rate: dev ? dev.changeRate : 0
    readonly property int pctLeft: dev ? Math.round(dev.timeToEmpty) : 0
    readonly property int pctFull: dev ? Math.round(dev.timeToFull) : 0

    // Waybar-parity bar text: "bat N%", "chg N%" while charging, "bat full"
    // when charged, "pwr" when plugged in but neither charging nor full.
    readonly property string barText: {
        if (!dev)
            return "bat";
        if (full)
            return "bat full";
        if (charging)
            return "chg " + pct + "%";
        if (dev.state === UPowerDeviceState.PendingCharge || dev.state === UPowerDeviceState.PendingDischarge)
            return "pwr";
        return "bat " + pct + "%";
    }

    // Waybar-parity tooltip: "4.2W↓ 87%" / "6.0W↑ 45%" (power draw + charge).
    readonly property string tooltipText: {
        if (!hasBattery)
            return "";
        const r = Math.abs(rate);
        const arrow = charging ? "↑" : "↓";
        if (r > 0.05)
            return r.toFixed(1) + "W" + arrow + " " + pct + "%";
        return pct + "%";
    }
}
