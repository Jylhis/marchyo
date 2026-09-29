pragma Singleton
import QtQuick
import Quickshell.Services.UPower
import qs.Commons

// Shared UPower derivations for the battery bar widget and the power panel:
// the composite display device plus the resolved percentage / state / rate.
// Also carries the waybar-parity formatting (bat / chg / pwr / bat full and
// the "N% (Nh Nm left)" line) so the widget and the panel cannot drift apart.
QtObject {
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.isLaptopBattery && dev.isPresent
    // UPower percentage is a 0.0–1.0 fraction (energy / energyCapacity); scale to 0–100.
    readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev && dev.state === UPowerDeviceState.FullyCharged
    // UPower energy-rate in W; positive while charging, negative while discharging.
    readonly property real rate: dev ? dev.changeRate : 0
    readonly property int pctLeft: dev ? Math.round(dev.timeToEmpty) : 0
    readonly property int pctFull: dev ? Math.round(dev.timeToFull) : 0

    // Bar glyph + value (waybar-parity states, compact icon form): battery glyph
    // + charge %, charging glyph while charging, a full glyph when charged, a
    // power-plug glyph when plugged in but neither charging nor full.
    readonly property string barText: {
        if (!dev)
            return "󰂑";
        if (full)
            return "󰁹";
        if (charging)
            return "󰂄 " + pct;
        if (dev.state === UPowerDeviceState.PendingCharge || dev.state === UPowerDeviceState.PendingDischarge)
            return "󰚥";
        return "󰁹 " + pct;
    }

    // Percentage tint as a continuous gradient between theme tokens rather than
    // switching colour at 10%/20% thresholds: the value reads as a ramp. 0% =
    // statusErr, 50% = statusWarn, 100% = statusOk. Shared by the bar widget and
    // the power panel so the two never disagree.
    function lerpColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color barColor: {
        const p = Math.max(0, Math.min(100, pct)) / 100;
        if (p < 0.5)
            return lerpColor(Color.statusErr, Color.statusWarn, p / 0.5);
        return lerpColor(Color.statusWarn, Color.statusOk, (p - 0.5) / 0.5);
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
