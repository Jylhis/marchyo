// Pure parsing and formatting for the speed test panel (Panels/SpeedtestPanel.qml
// over Services/Speedtest.qml). Dual citizenship like Format.js: QML imports it,
// tests/shell/speedtest-test.js loads it from Node. No Qt types, no I/O, no
// `.pragma` line.

// curl's `%{speed_download}` / `%{speed_upload}` (bytes per second) -> megabits
// per second, or -1 when the text is not a positive number.
function mbpsFromCurl(text) {
    var bytes = parseFloat(String(text == null ? "" : text).trim());
    if (!isFinite(bytes) || bytes <= 0)
        return -1;
    return (bytes * 8) / 1e6;
}

// curl's `%{time_starttransfer}` (seconds) -> whole milliseconds, or -1.
function pingMsFromCurl(text) {
    var s = parseFloat(String(text == null ? "" : text).trim());
    if (!isFinite(s) || s <= 0)
        return -1;
    return Math.max(1, Math.round(s * 1000));
}

// The summary line of GNU dd ("... copied, 0.4 s, 1.3 GB/s") -> MB/s (10^6
// bytes), or -1 when the line has no rate.
function mbPerSecFromDd(text) {
    var m = /,\s*([0-9]+(?:[.,][0-9]+)?)\s*(kB|KB|MB|GB|TB|KiB|MiB|GiB|TiB)\/s\s*$/m.exec(String(text == null ? "" : text));
    if (!m)
        return -1;
    var value = parseFloat(m[1].replace(",", "."));
    var unit = m[2];
    var factor = {
        kB: 1e-3,
        KB: 1e-3,
        MB: 1,
        GB: 1e3,
        TB: 1e6,
        KiB: 1.024e-3,
        MiB: 1.048576,
        GiB: 1073.741824,
        TiB: 1099511.627776
    }[unit];
    return value * factor;
}

// "123 Mbit/s", "0.8 Mbit/s", or an em-free dash for an unknown value.
function formatMbps(mbps) {
    if (!(mbps >= 0))
        return "-";
    return (mbps >= 10 ? Math.round(mbps) : Math.round(mbps * 10) / 10) + " Mbit/s";
}

function formatMBps(mbps) {
    if (!(mbps >= 0))
        return "-";
    return (mbps >= 10 ? Math.round(mbps) : Math.round(mbps * 10) / 10) + " MB/s";
}

function formatMs(ms) {
    return ms >= 0 ? ms + " ms" : "-";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {
        mbpsFromCurl: mbpsFromCurl,
        pingMsFromCurl: pingMsFromCurl,
        mbPerSecFromDd: mbPerSecFromDd,
        formatMbps: formatMbps,
        formatMBps: formatMBps,
        formatMs: formatMs
    };
