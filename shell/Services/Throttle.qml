pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../Commons/Format.js" as Format

// Performance-mode throttle warnings: power-profiles-daemon's degradation
// reason, Intel's thermal_throttle event counters, and a cpufreq policy cap
// below the hardware max. sysfs is sampled only while the performance profile
// is active; missing files (AMD, VMs) read as NaN and stay silent.
QtObject {
    id: root

    readonly property bool active: PowerProfileState.profile === PowerProfile.Performance

    readonly property string degradation: {
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return "lap";
        case PerformanceDegradationReason.HighTemperature:
            return "heat";
        default:
            return "";
        }
    }

    property real throttleDelta: NaN
    property real scalingMaxKhz: NaN
    property real cpuinfoMaxKhz: NaN
    property real _prevCount: NaN

    readonly property var warnings: root.active ? Format.throttleWarnings({
        degradation: root.degradation,
        throttleDelta: root.throttleDelta,
        scalingMaxKhz: root.scalingMaxKhz,
        cpuinfoMaxKhz: root.cpuinfoMaxKhz
    }) : []
    readonly property bool throttled: warnings.length > 0

    readonly property string _cpu0: "/sys/devices/system/cpu/cpu0/"
    property FileView _pkgCount: FileView {
        path: root._cpu0 + "thermal_throttle/package_throttle_count"
        blockLoading: true
        printErrors: false
    }
    property FileView _coreCount: FileView {
        path: root._cpu0 + "thermal_throttle/core_throttle_count"
        blockLoading: true
        printErrors: false
    }
    property FileView _scalingMax: FileView {
        path: root._cpu0 + "cpufreq/scaling_max_freq"
        blockLoading: true
        printErrors: false
    }
    property FileView _cpuinfoMax: FileView {
        path: root._cpu0 + "cpufreq/cpuinfo_max_freq"
        blockLoading: true
        printErrors: false
    }

    function _read(f): real {
        f.reload();
        return parseInt(f.text().trim());
    }

    // The first sample after entering performance only primes the counter.
    onActiveChanged: {
        root._prevCount = NaN;
        root.throttleDelta = NaN;
    }

    property Timer _timer: Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const count = root._read(root._pkgCount) + root._read(root._coreCount);
            root.throttleDelta = count - root._prevCount;
            root._prevCount = count;
            root.scalingMaxKhz = root._read(root._scalingMax);
            root.cpuinfoMaxKhz = root._read(root._cpuinfoMax);
        }
    }
}
