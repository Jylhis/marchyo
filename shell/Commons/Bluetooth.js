// Pure rules behind the Bluetooth panel (Panels/BluetoothPanel.qml): the order
// of the device list and the battery text. Dual citizenship like Format.js:
// QML imports it, tests/shell/bluetooth-test.js loads it from Node. No Qt
// types, no I/O, inputs are never mutated, no `.pragma` line.

// Connected devices first, then paired ones, then the rest; each group by name.
function sortRows(rows) {
    function rank(r) {
        return r.connected ? 0 : r.paired ? 1 : 2;
    }
    return (rows || []).slice().sort(function (a, b) {
        if (rank(a) !== rank(b))
            return rank(a) - rank(b);
        return String(a.name).localeCompare(String(b.name));
    });
}

// "87%" for a battery fraction (0..1) or percentage (0..100) that the device
// reports, "" when it reports none.
function batteryText(available, battery) {
    var n = Number(battery);
    if (!available || !isFinite(n) || n < 0)
        return "";
    var pct = n <= 1 ? n * 100 : n;
    return Math.round(Math.min(100, pct)) + "%";
}

// What a click on a row does: connected devices disconnect, paired ones
// connect, unknown ones pair (which also connects). A busy device does nothing.
function actionFor(row) {
    if (row.busy)
        return "none";
    if (row.connected)
        return "disconnect";
    return row.paired ? "connect" : "pair";
}

function hasHumanName(name) {
    var text = String(name || "").trim();
    return text !== "" && !/^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(text)
        && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
        && !/^[0-9a-f]{32}$/i.test(text) && !/^0x[0-9a-f]{4,32}$/i.test(text);
}

function sections(rows, scanning) {
    var groups = [
        { key: "connected", rows: [] },
        { key: "paired", rows: [] },
        { key: "available", rows: [] }
    ];
    sortRows(rows).forEach(function (row) {
        if (row.connected)
            groups[0].rows.push(row);
        else if (row.paired)
            groups[1].rows.push(row);
        else if (scanning && hasHumanName(row.name))
            groups[2].rows.push(row);
    });
    return groups.filter(function (group) { return group.rows.length > 0; });
}

function sinkMatchesDevice(node, device) {
    if (!node || !node.isSink || node.isStream || !device)
        return false;
    var props = node.properties || {};
    var text = [node.name, node.description, node.nickname,
        props["api.bluez5.address"], props["bluez5.address"], props["device.name"]]
        .join(" ").toLowerCase();
    if (!props["api.bluez5.address"] && !props["bluez5.address"] && !/bluez|bluetooth/.test(text))
        return false;
    var address = String(device.address || "").replace(/[^a-f0-9]/gi, "").toLowerCase();
    var addresses = text.match(/(?:[a-f0-9]{2}[:_-]){5}[a-f0-9]{2}/g) || [];
    if (address.length === 12)
        return addresses.some(function (value) {
            return value.replace(/[^a-f0-9]/g, "") === address;
        });
    return hasHumanName(device.name) && text.indexOf(device.name.toLowerCase()) !== -1;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {
        sortRows: sortRows,
        batteryText: batteryText,
        actionFor: actionFor,
        hasHumanName: hasHumanName,
        sections: sections,
        sinkMatchesDevice: sinkMatchesDevice
    };
