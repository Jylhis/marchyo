// Per-monitor workspace numbering for Bar/WorkspacesWidget.qml.
//
// Hyprland numbers workspaces globally; with marchyo.workspaces.perMonitor
// every monitor owns a block of ten ids (block 0 is 1-10, block 1 is 11-20)
// and the bar labels them 1-10. The block assignment comes from
// $XDG_STATE_HOME/marchyo/monitors/workspaces, written by
// modules/home/hyprland-monitor-workspaces.lua: one line per monitor,
// "<block>\t<connector>\t<identity>", the connector empty while unplugged.
//
// Same dual-citizenship arrangement as Format.js: QML imports this directly
// and ignores the CommonJS guard at the bottom. Must stay pure.

var SLOTS = 10;

// Connector -> block from the state file text.
function parseBlocks(text) {
    var blocks = {};
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var fields = lines[i].split("\t");
        if (fields.length >= 3 && fields[1] !== "" && /^\d+$/.test(fields[0]))
            blocks[fields[1]] = parseInt(fields[0], 10);
    }
    return blocks;
}

function blockOf(id) {
    return Math.floor((id - 1) / SLOTS);
}

function slotOf(id) {
    return ((id - 1) % SLOTS) + 1;
}

// The monitor's block: the state file's, else the block of the workspace it
// shows (before Hyprland has written the file), else 0.
function blockFor(blocks, monitorName, activeId) {
    if (blocks && blocks[monitorName] !== undefined)
        return blocks[monitorName];
    return activeId > 0 ? blockOf(activeId) : 0;
}

// Ids for one monitor's bar: the first `persistent` slots of its block, any
// other existing workspace of the block, then guests (workspaces of another
// block shown on this monitor), each group ascending. `workspaces` is a list
// of { id, monitor } with monitor a connector name.
function workspaceIds(block, workspaces, monitorName, persistent) {
    var base = block * SLOTS;
    var own = [];
    var guests = [];
    var count = persistent === undefined ? 5 : persistent;
    for (var s = 1; s <= count; s++)
        own.push(base + s);
    for (var i = 0; i < (workspaces || []).length; i++) {
        var ws = workspaces[i];
        if (!ws || ws.id <= 0)
            continue;
        if (blockOf(ws.id) === block) {
            if (own.indexOf(ws.id) === -1)
                own.push(ws.id);
        } else if (ws.monitor === monitorName && guests.indexOf(ws.id) === -1) {
            guests.push(ws.id);
        }
    }
    var asc = function (a, b) {
        return a - b;
    };
    own.sort(asc);
    guests.sort(asc);
    return own.concat(guests);
}

// What the bar shows for an id: its slot within the monitor's own block, the
// global id for a guest.
function label(id, block) {
    return blockOf(id) === block ? String(slotOf(id)) : String(id);
}

// Node (tests) picks this up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        SLOTS: SLOTS,
        parseBlocks: parseBlocks,
        blockOf: blockOf,
        slotOf: slotOf,
        blockFor: blockFor,
        workspaceIds: workspaceIds,
        label: label
    };
