pragma Singleton
import QtQuick
import Quickshell.Io

// Shared system-resource sampler: CPU busy-fraction (from /proc/stat) and memory
// use (from /proc/meminfo), polled once on a single timer so the bar's CpuWidget
// and the summonable MonitorPanel read one source of truth instead of each
// running its own drifting sampler. Cheap sysfs reads, so it runs always-on (like
// the bar's other native bindings); disk/temperature stay in the panel, polled
// only while it is open. No IPC, no manifest — a plain qs.Services singleton, the
// same shape as PanelManager.
QtObject {
    id: root

    // CPU busy percentage between the last two samples (0 on the priming tick).
    property int cpuUsage: 0
    // Memory in kB, plus the derived percentage.
    property real memUsedKb: 0
    property real memTotalKb: 0
    readonly property int memPercent: memTotalKb > 0 ? Math.round(100 * memUsedKb / memTotalKb) : 0

    // /proc/stat deltas need the previous sample; the first tick just primes them.
    property real _prevIdle: 0
    property real _prevTotal: 0

    property FileView _stat: FileView {
        id: statView
        path: "/proc/stat"
        blockLoading: true
    }

    property FileView _mem: FileView {
        id: memView
        path: "/proc/meminfo"
        blockLoading: true
    }

    property Timer _timer: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // CPU: busy fraction of the total jiffy delta (idle = idle + iowait).
            statView.reload();
            const f = statView.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (f.length >= 5) {
                const idle = f[3] + f[4];
                const total = f.reduce((a, b) => a + b, 0);
                const dIdle = idle - root._prevIdle;
                const dTotal = total - root._prevTotal;
                root._prevIdle = idle;
                root._prevTotal = total;
                if (dTotal > 0)
                    root.cpuUsage = Math.round(100 * (dTotal - dIdle) / dTotal);
            }

            // Memory: MemAvailable is the kernel's own "usable without swapping"
            // figure (present since 3.14) — more accurate than total-free-buffers-cached.
            memView.reload();
            const m = {};
            memView.text().split("\n").forEach(l => {
                const mm = l.match(/^(\w+):\s+(\d+)\s*kB/);
                if (mm)
                    m[mm[1]] = Number(mm[2]);
            });
            if (m.MemTotal) {
                root.memTotalKb = m.MemTotal;
                root.memUsedKb = m.MemTotal - (m.MemAvailable !== undefined ? m.MemAvailable : m.MemFree);
            }
        }
    }
}
