pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import "../Commons/Format.js" as Format

// Shared UPower derivations for the battery bar widget and the power panel:
// the composite display device plus the resolved percentage / state / rate,
// the drain-on-AC condition, and the rated watts of a USB-C charger. Also
// carries the waybar-parity formatting (bat / chg / pwr / bat full and the
// "N% (Nh Nm left)" line) so the widget and the panel cannot drift apart.
QtObject {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.isLaptopBattery && dev.isPresent
    // UPower percentage is a 0.0–1.0 fraction (energy / energyCapacity); scale to 0–100.
    readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: dev && dev.state === UPowerDeviceState.Discharging
    readonly property bool pluggedIn: !UPower.onBattery
    // UPower energy-rate in W; positive while charging, negative while discharging.
    readonly property real rate: dev ? dev.changeRate : 0
    readonly property int pctLeft: dev ? Math.round(dev.timeToEmpty) : 0
    readonly property int pctFull: dev ? Math.round(dev.timeToFull) : 0
    readonly property real energyWh: dev ? dev.energy : 0
    readonly property real capacityWh: dev ? dev.energyCapacity : 0
    // Plugged in, yet the battery still drains: the charger cannot cover the
    // load. The 0.5 W floor ignores UPower's brief state flips on plug-in.
    readonly property bool drainingOnAc: hasBattery && pluggedIn && discharging && Math.abs(rate) > 0.5

    // Rated watts of the best online external supply (0 when the kernel does
    // not report one, e.g. a plain ACPI "Mains" adapter).
    property int chargerW: 0

    property var _supplyDirs: []

    property Process _supplyScan: Process {
        running: true
        command: [Config.ls, "/sys/class/power_supply"]
        stdout: StdioCollector {
            onStreamFinished: root._supplyDirs = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0).map(d => "/sys/class/power_supply/" + d)
        }
    }

    property Instantiator _supplies: Instantiator {
        model: root._supplyDirs
        delegate: FileView {
            required property string modelData
            path: modelData + "/uevent"
            blockLoading: true
            printErrors: false
        }
        onObjectAdded: root._refreshCharger()
    }

    function _refreshCharger(): void {
        let w = 0;
        for (let i = 0; i < _supplies.count; i++) {
            const f = _supplies.objectAt(i) as FileView;
            if (!f)
                continue;
            f.reload();
            w = Math.max(w, Format.supplyWatts(f.text()));
        }
        root.chargerW = w;
    }

    // USB-C PD negotiation lands a moment after UPower flips onBattery.
    onPluggedInChanged: _chargerSettle.restart()
    property Timer _chargerSettle: Timer {
        interval: 2000
        onTriggered: root._refreshCharger()
    }

    // Bar glyph + value (waybar-parity states, compact icon form): battery glyph
    // + charge %, charging glyph while charging, a full glyph when charged, a
    // power-plug glyph when plugged in but neither charging nor full, and an
    // alert glyph when plugged in but still draining.
    readonly property string barText: {
        if (!dev)
            return "󰂑";
        if (full)
            return "󰁹";
        if (charging)
            return "󰂄 " + pct;
        if (drainingOnAc)
            return "󰂃 " + pct;
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
        const s = r > 0.05 ? (r.toFixed(1) + "W" + arrow + " " + pct + "%") : (pct + "%");
        return drainingOnAc ? (s + " · plugged in, still draining") : s;
    }
}
