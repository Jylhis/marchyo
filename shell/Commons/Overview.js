// Pure helpers for the window overview (Services/Overview, Overview/):
// window normalization, grouping by workspace, search filtering, keyboard
// navigation order and the tile layout math.
//
// Dual citizenship like Format.js: QML imports this file and ignores the
// CommonJS guard, Node loads it in tests/shell/overview-test.js. Stay pure (no
// Qt types, no I/O) and never add a `.pragma` directive (Node cannot parse one;
// pinned by contracts-test.sh).
//
// A window here is a plain object:
//   { address, title, cls, workspaceId, workspaceName, monitorId,
//     x, y, w, h, floating, focusHistory }
// in Hyprland's global layout coordinates. `address` always carries the "0x"
// prefix `focuswindow address:` expects.

function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
}

// An [a, b] pair from a JS array or an array-like (a lastIpcObject list
// reaches JS as a sequence type, not an Array).
function pair(v) {
    return v && typeof v === "object" && typeof v.length === "number" && v.length >= 2 ? [v[0], v[1]] : [0, 0];
}

function hexAddress(a) {
    var s = String(a == null ? "" : a).trim();
    if (s.length === 0)
        return "";
    return s.indexOf("0x") === 0 ? s : "0x" + s;
}

// One `hyprctl clients -j` record (a HyprlandToplevel's lastIpcObject) to a
// window, or null when it has no address, is unmapped or hidden (a grouped
// tab behind its head), or lives on a special workspace (negative id).
function normalizeWindow(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    var address = hexAddress(raw.address);
    if (address.length === 0 || raw.mapped === false || raw.hidden === true)
        return null;
    var ws = raw.workspace && typeof raw.workspace === "object" ? raw.workspace : {};
    var wsId = num(ws.id, 0);
    if (wsId <= 0)
        return null;
    var at = pair(raw.at);
    var size = pair(raw.size);
    return {
        address: address,
        title: String(raw.title == null ? "" : raw.title),
        cls: String(raw["class"] == null ? "" : raw["class"]),
        workspaceId: wsId,
        workspaceName: String(ws.name == null ? String(wsId) : ws.name),
        monitorId: num(raw.monitor, -1),
        x: num(at[0], 0),
        y: num(at[1], 0),
        w: Math.max(0, num(size[0], 0)),
        h: Math.max(0, num(size[1], 0)),
        floating: raw.floating === true,
        focusHistory: num(raw.focusHistoryID, 1e9)
    };
}

// A monitor's logical rectangle (layout coordinates): Hyprland reports pixel
// width/height, windows live in pixel / scale; a 90/270 degree transform
// (odd values) swaps the axes.
function monitorRect(mon) {
    if (!mon || typeof mon !== "object")
        return null;
    var scale = num(mon.scale, 1);
    if (scale <= 0)
        scale = 1;
    var w = num(mon.width, 0) / scale;
    var h = num(mon.height, 0) / scale;
    if (num(mon.transform, 0) % 2 === 1) {
        var t = w;
        w = h;
        h = t;
    }
    return {
        id: num(mon.id, -1),
        name: String(mon.name == null ? "" : mon.name),
        x: num(mon.x, 0),
        y: num(mon.y, 0),
        w: w,
        h: h
    };
}

// Reading order inside a workspace: tiled before floating, then top-to-bottom,
// then left-to-right.
function byPosition(a, b) {
    if (a.floating !== b.floating)
        return a.floating ? 1 : -1;
    if (a.y !== b.y)
        return a.y - b.y;
    if (a.x !== b.x)
        return a.x - b.x;
    return a.address < b.address ? -1 : a.address > b.address ? 1 : 0;
}

// Workspaces (ascending id) with their windows in reading order. `workspaces`
// lists the known regular workspaces as { id, name, monitorId } (empty ones
// included, special ones skipped); a window on a workspace not in that list
// still gets one.
function groupByWorkspace(windows, workspaces) {
    var byId = {};
    var groups = [];
    function groupFor(id, name, monitorId) {
        if (!byId[id]) {
            byId[id] = {
                id: id,
                name: name,
                monitorId: monitorId,
                windows: []
            };
            groups.push(byId[id]);
        }
        return byId[id];
    }
    (workspaces || []).forEach(function (ws) {
        var id = num(ws && ws.id, 0);
        if (id > 0)
            groupFor(id, String(ws.name == null ? String(id) : ws.name), num(ws.monitorId, -1));
    });
    (windows || []).forEach(function (w) {
        if (w && w.workspaceId > 0)
            groupFor(w.workspaceId, w.workspaceName, w.monitorId).windows.push(w);
    });
    groups.sort(function (a, b) {
        return a.id - b.id;
    });
    groups.forEach(function (g) {
        g.windows.sort(byPosition);
    });
    return groups;
}

// The search filter: address -> score for every window whose title or class
// matches `query` under `scoreFn(text, query)` (a score >= 0 is a match, -1 is
// none). An empty query matches every window with score 0.
function filterWindows(windows, query, scoreFn) {
    var q = String(query == null ? "" : query).trim();
    var out = {};
    (windows || []).forEach(function (w) {
        if (q.length === 0) {
            out[w.address] = 0;
            return;
        }
        var s = Math.max(scoreFn(w.title, q), scoreFn(w.cls, q));
        if (s >= 0)
            out[w.address] = s;
    });
    return out;
}

// Addresses of the matching windows in display order (workspace by workspace,
// reading order inside each): the keyboard navigation sequence.
function navOrder(groups, matches) {
    var order = [];
    (groups || []).forEach(function (g) {
        g.windows.forEach(function (w) {
            if (matches && Object.prototype.hasOwnProperty.call(matches, w.address))
                order.push(w.address);
        });
    });
    return order;
}

// The window a fresh query selects: the best-scoring match (display order
// breaks ties), or for an empty query the most recently focused window. ""
// when nothing matches.
function bestMatch(groups, matches, query) {
    var order = navOrder(groups, matches);
    if (order.length === 0)
        return "";
    var q = String(query == null ? "" : query).trim();
    var all = {};
    (groups || []).forEach(function (g) {
        g.windows.forEach(function (w) {
            all[w.address] = w;
        });
    });
    var best = order[0];
    for (var i = 1; i < order.length; i++) {
        var a = order[i];
        if (q.length === 0 ? all[a].focusHistory < all[best].focusHistory : matches[a] > matches[best])
            best = a;
    }
    return best;
}

// Step `delta` through the navigation order from `current`, wrapping. An
// unknown or empty `current` lands on the first (delta > 0) or last entry.
function step(order, current, delta) {
    var n = (order || []).length;
    if (n === 0)
        return "";
    var i = order.indexOf(current);
    if (i < 0)
        return delta < 0 ? order[n - 1] : order[0];
    return order[((i + delta) % n + n) % n];
}

// Move one grid row up (delta -1) or down (+1) from `current`: the first
// matching window of the nearest workspace `cols` tiles away in that
// direction that has one. Stays on `current` when there is none; an unknown
// `current` behaves like step().
function stepRow(groups, matches, current, delta, cols) {
    var c = Math.max(1, cols | 0);
    var gs = groups || [];
    var at = -1;
    for (var i = 0; i < gs.length && at < 0; i++)
        for (var k = 0; k < gs[i].windows.length; k++)
            if (gs[i].windows[k].address === current)
                at = i;
    if (at < 0)
        return step(navOrder(gs, matches), current, delta);
    for (var j = at + delta * c; j >= 0 && j < gs.length; j += delta * c) {
        var hit = navOrder([gs[j]], matches);
        if (hit.length > 0)
            return hit[0];
    }
    return current;
}

// Columns for `count` workspace tiles: a wide grid (about 3:2 tiles across
// rows), capped at `maxCols`.
function gridColumns(count, maxCols) {
    var n = Math.max(1, count | 0);
    var cap = Math.max(1, maxCols | 0);
    return Math.max(1, Math.min(n, cap, Math.ceil(Math.sqrt(n * 1.5))));
}

// The largest tile of aspect ratio `aspect` (w / h) such that `cols` x `rows`
// of them, `gap` apart, fit in areaW x areaH.
function tileSize(areaW, areaH, cols, rows, gap, aspect) {
    var c = Math.max(1, cols | 0);
    var r = Math.max(1, rows | 0);
    var g = Math.max(0, num(gap, 0));
    var a = num(aspect, 16 / 9) > 0 ? num(aspect, 16 / 9) : 16 / 9;
    var maxW = Math.max(0, (num(areaW, 0) - g * (c - 1)) / c);
    var maxH = Math.max(0, (num(areaH, 0) - g * (r - 1)) / r);
    var w = Math.min(maxW, maxH * a);
    return {
        w: Math.floor(w),
        h: Math.floor(w / a)
    };
}

// A window's rectangle inside a tileW x tileH workspace tile showing monitor
// `mon` (a monitorRect), uniformly scaled and clamped to the tile. A window
// with no known monitor falls back to its own position from the origin.
function windowRect(win, mon, tileW, tileH) {
    var m = mon || {
        x: 0,
        y: 0,
        w: tileW,
        h: tileH
    };
    var s = m.w > 0 && m.h > 0 ? Math.min(tileW / m.w, tileH / m.h) : 1;
    var x = Math.max(0, Math.min(tileW, (win.x - m.x) * s));
    var y = Math.max(0, Math.min(tileH, (win.y - m.y) * s));
    return {
        x: x,
        y: y,
        w: Math.max(1, Math.min(tileW - x, win.w * s)),
        h: Math.max(1, Math.min(tileH - y, win.h * s))
    };
}

// CommonJS guard: QML ignores this, Node requires it (see format-test.js).
if (typeof module !== "undefined" && module.exports)
    module.exports = {
        normalizeWindow: normalizeWindow,
        monitorRect: monitorRect,
        groupByWorkspace: groupByWorkspace,
        filterWindows: filterWindows,
        navOrder: navOrder,
        bestMatch: bestMatch,
        step: step,
        stepRow: stepRow,
        gridColumns: gridColumns,
        tileSize: tileSize,
        windowRect: windowRect
    };
