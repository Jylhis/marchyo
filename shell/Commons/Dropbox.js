// Pure parsing of `dropbox status` for the Dropbox panel (Panels/DropboxPanel.qml
// over Services/Dropbox.qml). Dual citizenship like Format.js: QML imports it,
// tests/shell/dropbox-test.js loads it from Node. No Qt types, no I/O, no
// `.pragma` line.

// state: "stopped" (the daemon is not running), "idle" (up to date),
// "syncing", "connecting" or "unknown". `detail` is the CLI's first line.
function parseStatus(text) {
    var line = String(text == null ? "" : text).split("\n")[0].trim();
    var lower = line.toLowerCase();
    var state = "unknown";
    if (lower === "")
        state = "unknown";
    else if (lower.indexOf("isn't running") >= 0 || lower.indexOf("not running") >= 0)
        state = "stopped";
    else if (lower.indexOf("up to date") >= 0)
        state = "idle";
    else if (lower.indexOf("sync") >= 0 || lower.indexOf("download") >= 0 || lower.indexOf("upload") >= 0 || lower.indexOf("indexing") >= 0)
        state = "syncing";
    else if (lower.indexOf("connecting") >= 0 || lower.indexOf("starting") >= 0 || lower.indexOf("waiting") >= 0)
        state = "connecting";
    return {
        state: state,
        detail: line
    };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {
        parseStatus: parseStatus
    };
