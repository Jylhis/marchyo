// Pure logic of the display panel (Panels/DisplayPanel.qml): the display model,
// mode/scale/refresh choices, layout placement, rotation, the Lua that applies
// a change and the saved-settings file.
//
// Layout rects are { name, x, y, w, h } in Hyprland's layout space: logical
// pixels, after each display's scale and rotation.
//
// Plain JavaScript with a CommonJS guard (no `.pragma`, see Format.js) so
// tests/shell/displays-test.js covers it headlessly. Stays pure: no Qt types,
// no globals, no I/O. Inputs are never mutated.
//
// Adapted from Omarchy's shell/plugins/panels/monitor/Model.js (MIT).

var INTERNAL = /^(eDP|LVDS|DSI)-/;
var SAFE_NAME = /^[A-Za-z0-9._-]+$/;

// Scales the panel offers, before each mode snaps them to ones Hyprland takes.
var SCALE_PRESETS = [1, 1.25, 1.5, 1.75, 2, 2.5, 3];

// Logical pixels a layout tile moves per Shift+arrow press.
var NUDGE_STEP = 160;

var RESOLUTION_LIMIT = 5;
var RESOLUTION_MIN_HEIGHT = 1080;
var REFRESH_MIN = 59.5;

function isInternal(name) {
    return INTERNAL.test(String(name || ""));
}

function clampBrightness(value) {
    var n = Number(value);
    if (!isFinite(n))
        return 1;
    return Math.max(1, Math.min(100, Math.round(n)));
}

function normalizeScale(scale) {
    var n = parseFloat(String(scale || ""));
    if (!isFinite(n))
        return "";
    return String(Math.round(n * 100) / 100);
}

function gcd(a, b) {
    while (b) {
        var r = a % b;
        a = b;
        b = r;
    }
    return a;
}

// Hyprland only takes scales where the mode divides into whole logical pixels
// (in 1/120 steps), so a clean scale divides gcd(w*120, h*120). Rounds the
// requested scale up to the nearest clean one; "" for unusable input.
function cleanScale(scale, width, height) {
    var requested = Number(scale);
    var w = Number(width);
    var h = Number(height);
    if (!isFinite(requested) || !isFinite(w) || !isFinite(h) || requested <= 0 || w <= 0 || h <= 0)
        return "";
    var divisor = gcd(Math.round(w * 120), Math.round(h * 120));
    var units = Math.round(requested * 120);
    if (units < 1)
        units = 1;
    if (units > divisor)
        units = divisor;
    while (divisor % units !== 0)
        units++;
    return normalizeScale(units / 120);
}

// The scale choices for a mode: each preset snapped to a clean value, one per
// effective scale, in preset order.
function availableScales(width, height, presets) {
    var list = Array.isArray(presets) ? presets : SCALE_PRESETS;
    var seen = {};
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var clean = cleanScale(list[i], width, height);
        if (clean === "" || seen[clean])
            continue;
        seen[clean] = true;
        out.push(Number(clean));
    }
    return out;
}

// The obvious resolutions, smallest first: the native one, then smaller modes
// of the same aspect ratio down to 1080p, so nothing comes out stretched. Odd
// legacy modes stay out, the list stops at a handful, and the current
// resolution always shows.
function resolutionOptions(availableModes, width, height) {
    if (!Array.isArray(availableModes))
        return [];
    var sizes = {};
    for (var i = 0; i < availableModes.length; i++) {
        var m = /^(\d+)x(\d+)@/.exec(String(availableModes[i]));
        if (!m)
            continue;
        var w = Number(m[1]);
        var h = Number(m[2]);
        if (w > 0 && h > 0)
            sizes[w + "x" + h] = { w: w, h: h };
    }
    var all = Object.keys(sizes).map(function (k) {
        return sizes[k];
    });
    if (all.length === 0)
        return [];
    all.sort(function (a, b) {
        return b.w * b.h - a.w * a.h || b.w - a.w;
    });
    var native = all[0];
    var aspect = native.w / native.h;
    var options = all.filter(function (s) {
        return s.h >= RESOLUTION_MIN_HEIGHT && Math.abs(s.w / s.h - aspect) < 0.01;
    }).slice(0, RESOLUTION_LIMIT).map(function (s) {
        return s.w + "x" + s.h;
    });
    var current = Number(width) + "x" + Number(height);
    if (sizes[current] && options.indexOf(current) < 0) {
        options.push(current);
        options.sort(function (a, b) {
            return sizes[b].w * sizes[b].h - sizes[a].w * sizes[a].h;
        });
    }
    return options.reverse();
}

// Short pill label: the names people know (4K, 1440p), else the height.
function resolutionLabel(resolution) {
    var m = /^(\d+)x(\d+)$/.exec(String(resolution));
    if (!m)
        return String(resolution);
    var w = Number(m[1]);
    var h = Number(m[2]);
    if (h >= 4320)
        return "8K";
    if (w >= 6000)
        return "6K";
    if (w >= 5120 && h >= 2880)
        return "5K";
    if (w >= 3840 && h >= 2160)
        return "4K";
    return h + "p";
}

// The refresh rates offered at the current resolution, slowest first: one per
// whole rate (59.94 and 60 are one choice), from 60 Hz up. Empty unless one is
// faster than 60 Hz.
function refreshOptions(availableModes, width, height) {
    if (!Array.isArray(availableModes))
        return [];
    var prefix = Number(width) + "x" + Number(height) + "@";
    var rates = {};
    for (var i = 0; i < availableModes.length; i++) {
        var mode = String(availableModes[i]);
        if (mode.indexOf(prefix) !== 0)
            continue;
        var rate = parseFloat(mode.slice(prefix.length));
        if (!(rate >= REFRESH_MIN))
            continue;
        var whole = Math.round(rate);
        if (!rates[whole] || rate > rates[whole])
            rates[whole] = rate;
    }
    var wholes = Object.keys(rates).map(Number).sort(function (a, b) {
        return a - b;
    });
    if (wholes.length < 2 || wholes[wholes.length - 1] <= 60)
        return [];
    return wholes.map(function (w) {
        return { label: String(w), rate: String(Number(rates[w].toFixed(2))) };
    });
}

// The mode string for a size at a rate; without a rate, the fastest the
// monitor advertises for that size. "" when the monitor has no such mode.
function modeFor(availableModes, size, rate) {
    if (!Array.isArray(availableModes))
        return "";
    var best = null;
    for (var i = 0; i < availableModes.length; i++) {
        var m = /^(\d+x\d+)@([0-9.]+)Hz$/.exec(String(availableModes[i]));
        if (!m || m[1] !== size)
            continue;
        var r = parseFloat(m[2]);
        if (rate !== undefined && rate !== null && rate !== "" && Math.abs(r - Number(rate)) >= 0.01)
            continue;
        if (best === null || r > best)
            best = r;
    }
    return best === null ? "" : size + "@" + String(Math.round(best * 100) / 100);
}

// ---- Rotation ----
// Hyprland's transforms 0-3 are quarter turns clockwise; 4-7 mirror them.

function transformFor(degrees) {
    var i = [0, 90, 180, 270].indexOf(Number(degrees));
    return i;
}

function degreesOf(transform) {
    var t = Number(transform) || 0;
    return t < 4 ? t * 90 : -1;
}

// The next quarter turn for a right-click; a flipped transform turns upright.
function nextRotation(transform) {
    var t = Number(transform) || 0;
    return t < 4 ? (t + 1) % 4 : 0;
}

// A footprint after a transform change: swapped when the turn changes which
// way the monitor stands.
function turnedSize(w, h, oldTransform, newTransform) {
    if ((Number(oldTransform) || 0) % 2 === (Number(newTransform) || 0) % 2)
        return { w: w, h: h };
    return { w: h, h: w };
}

// ---- Display model ----

function identityOf(display) {
    var d = String((display && display.description) || "").trim();
    return d !== "" ? d : String((display && display.name) || "");
}

// What to call a display: the built-in panel by what it is, since laptops
// report a panel code as the model, and any other by its model, else its make,
// else its connector.
function displayTitle(display, builtInLabel) {
    var name = String((display && display.name) || "");
    if (isInternal(name))
        return builtInLabel || "Built-in Display";
    var model = String(display.model || "").trim();
    if (model && !/^(0x)?[0-9a-f]+$/i.test(model))
        return model;
    return String(display.make || "").trim() || name;
}

// `hyprctl monitors all -j` into the panel's model. mirrorOf comes as the
// mirrored monitor's id; it is named here.
function parseDisplays(raw) {
    var list = [];
    try {
        list = raw ? JSON.parse(String(raw)) : [];
    } catch (e) {
        list = [];
    }
    if (!Array.isArray(list))
        return [];
    var names = {};
    list.forEach(function (m) {
        if (m && m.name)
            names[String(m.id)] = String(m.name);
    });
    var out = [];
    list.forEach(function (m) {
        if (!m || !SAFE_NAME.test(String(m.name || "")))
            return;
        var mirror = m.mirrorOf === undefined || m.mirrorOf === null || m.mirrorOf === "none" ? "" : (names[String(m.mirrorOf)] || String(m.mirrorOf));
        out.push({
            name: String(m.name),
            identity: identityOf(m),
            make: String(m.make || ""),
            model: String(m.model || ""),
            enabled: m.disabled !== true,
            focused: m.focused === true,
            internal: isInternal(m.name),
            width: Number(m.width) || 0,
            height: Number(m.height) || 0,
            refreshRate: Number(m.refreshRate) || 0,
            scale: Number(m.scale) || 1,
            x: Number(m.x) || 0,
            y: Number(m.y) || 0,
            transform: Number(m.transform) || 0,
            mirrorOf: mirror,
            modes: Array.isArray(m.availableModes) ? m.availableModes.map(String) : []
        });
    });
    return out;
}

// Displays that take part in the layout: enabled and not mirroring another.
function layoutDisplays(displays) {
    return (displays || []).filter(function (d) {
        return d.enabled && d.mirrorOf === "";
    });
}

function enabledCount(displays) {
    return (displays || []).filter(function (d) {
        return d.enabled;
    }).length;
}

// Whether Extend|Mirror shows: a built-in panel on and at least one external.
function canMirror(displays) {
    var list = displays || [];
    var internal = list.some(function (d) {
        return d.internal && d.enabled;
    });
    var external = list.some(function (d) {
        return !d.internal && d.enabled;
    });
    return internal && external;
}

function isMirrored(displays) {
    return (displays || []).some(function (d) {
        return !d.internal && d.enabled && d.mirrorOf !== "";
    });
}

// ---- Layout ----

// A display's footprint: its mode divided by its scale, on its side when
// rotated a quarter turn.
function logicalRect(display) {
    var scale = Number(display.scale) || 1;
    var w = Math.round(Number(display.width) / scale);
    var h = Math.round(Number(display.height) / scale);
    if (Number(display.transform) % 2 === 1) {
        var t = w;
        w = h;
        h = t;
    }
    return { name: String(display.name), x: Number(display.x) || 0, y: Number(display.y) || 0, w: w, h: h };
}

function copyRects(rects) {
    var list = [];
    for (var i = 0; rects && i < rects.length; i++)
        list.push({ name: rects[i].name, x: rects[i].x, y: rects[i].y, w: rects[i].w, h: rects[i].h });
    return list;
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function anyOverlap(rects) {
    for (var i = 0; i < rects.length; i++)
        for (var j = i + 1; j < rects.length; j++)
            if (overlaps(rects[i], rects[j]))
                return true;
    return false;
}

function layoutBounds(rects) {
    var b = { x: Infinity, y: Infinity, right: -Infinity, bottom: -Infinity };
    for (var i = 0; i < rects.length; i++) {
        b.x = Math.min(b.x, rects[i].x);
        b.y = Math.min(b.y, rects[i].y);
        b.right = Math.max(b.right, rects[i].x + rects[i].w);
        b.bottom = Math.max(b.bottom, rects[i].y + rects[i].h);
    }
    b.w = b.right - b.x;
    b.h = b.bottom - b.y;
    return b;
}

// Shift the layout so it starts at 0x0, as Hyprland's own does.
function normalizeLayout(rects) {
    var b = layoutBounds(rects);
    return rects.map(function (r) {
        return { name: r.name, x: r.x - b.x, y: r.y - b.y, w: r.w, h: r.h };
    });
}

// Along an edge shared with another display: keep at least a pixel of the edge
// shared, and take the other's start, centre or end when within snap.
function alignAlong(pos, size, start, length, snap) {
    var aligned = Math.round(Math.max(start - size + 1, Math.min(start + length - 1, pos)));
    var targets = [start, start + (length - size) / 2, start + length - size];
    var best = aligned;
    var bestDistance = snap;
    for (var i = 0; i < targets.length; i++) {
        var d = Math.abs(aligned - targets[i]);
        if (d <= bestDistance) {
            best = Math.round(targets[i]);
            bestDistance = d;
        }
    }
    return best;
}

// Where a display dropped with its corner at (x, y) lands: against a side of
// one of the others, at the spot nearest the drop that overlaps nothing.
// Returns the whole layout, normalised, or null when nothing fits.
function dropDisplay(rects, name, x, y, snap) {
    var all = copyRects(rects);
    var moving = null;
    var others = [];
    for (var i = 0; i < all.length; i++) {
        if (all[i].name === name)
            moving = all[i];
        else
            others.push(all[i]);
    }
    if (!moving || others.length === 0)
        return null;
    var best = null;
    var bestDistance = Infinity;
    for (var j = 0; j < others.length; j++) {
        var o = others[j];
        var alongY = alignAlong(y, moving.h, o.y, o.h, snap);
        var alongX = alignAlong(x, moving.w, o.x, o.w, snap);
        var candidates = [
            { x: o.x - moving.w, y: alongY },
            { x: o.x + o.w, y: alongY },
            { x: alongX, y: o.y - moving.h },
            { x: alongX, y: o.y + o.h }
        ];
        for (var c = 0; c < candidates.length; c++) {
            var placed = { name: name, x: candidates[c].x, y: candidates[c].y, w: moving.w, h: moving.h };
            if (others.some(function (r) {
                return overlaps(placed, r);
            }))
                continue;
            var dist = Math.hypot(placed.x - x, placed.y - y);
            if (dist < bestDistance) {
                best = placed;
                bestDistance = dist;
            }
        }
    }
    if (!best)
        return null;
    return normalizeLayout(all.map(function (r) {
        return r.name === name ? best : r;
    }));
}

function placeBeside(rects, name, target, right) {
    var moving = rects.find(function (r) { return r.name === name; });
    var beside = rects.find(function (r) { return r.name === target; });
    if (!moving || !beside || name === target)
        return null;
    var placed = copyRects(rects).map(function (r) {
        if (r.name === name) {
            r.x = right ? beside.x + beside.w : beside.x - moving.w;
            r.y = beside.y;
        }
        return r;
    });
    return anyOverlap(placed) ? null : normalizeLayout(placed);
}

function mirrorMatches(displays, wanted) {
    var external = (displays || []).filter(function (d) { return d.enabled && !d.internal; });
    var internal = (displays || []).find(function (d) { return d.enabled && d.internal; });
    return !!internal && external.length > 0 && external.every(function (d) {
        return wanted ? d.mirrorOf === internal.name : d.mirrorOf === "";
    });
}

function sameLayout(a, b) {
    if (!a || !b || a.length !== b.length)
        return false;
    for (var i = 0; i < a.length; i++) {
        var match = null;
        for (var j = 0; j < b.length; j++)
            if (b[j].name === a[i].name)
                match = b[j];
        if (!match || match.x !== a[i].x || match.y !== a[i].y)
            return false;
    }
    return true;
}

// A display changed size (new mode, scale or rotation). It keeps its corner;
// every display to its right or below shifts by the growth, so the displays
// that touched it still do. Shifting sideways and down at once can push two
// neighbours onto each other, so while any overlap remains a shifted display
// goes back where it was whenever that spot is free; a gap beats a pile-up.
// Returns { rects, order }: the new layout (not normalised, so the resized
// display's corner stays) and the names in an order whose steps never overlap
// (those moving away first, farthest first, then the resized one, then those
// closing in, nearest first).
function resizeLayout(rects, name, newW, newH) {
    var old = copyRects(rects);
    var m = null;
    old.forEach(function (r) {
        if (r.name === name)
            m = r;
    });
    if (!m)
        return { rects: old, order: [] };
    var next = old.map(function (r) {
        if (r.name === name)
            return { name: r.name, x: r.x, y: r.y, w: newW, h: newH };
        return {
            name: r.name,
            w: r.w,
            h: r.h,
            x: r.x >= m.x + m.w ? r.x + (newW - m.w) : r.x,
            y: r.y >= m.y + m.h ? r.y + (newH - m.h) : r.y
        };
    });
    function origin(n) {
        return old.filter(function (r) {
            return r.name === n;
        })[0];
    }
    var guard = next.length * 2;
    while (anyOverlap(next) && guard-- > 0) {
        var restorable = [];
        for (var i = 0; i < next.length; i++) {
            var a = next[i];
            var o = origin(a.name);
            if (a.x === o.x && a.y === o.y)
                continue;
            var back = { name: a.name, x: o.x, y: o.y, w: a.w, h: a.h };
            var free = next.every(function (r) {
                return r.name === a.name || !overlaps(back, r);
            });
            if (!free)
                continue;
            var touching = next.some(function (r) {
                return r.name !== a.name && overlaps(a, r);
            });
            restorable.push({ i: i, back: back, touching: touching });
        }
        if (restorable.length === 0)
            break;
        restorable.sort(function (p, q) {
            return (q.touching ? 1 : 0) - (p.touching ? 1 : 0);
        });
        next[restorable[0].i] = restorable[0].back;
    }
    if (anyOverlap(next)) {
        var kept = old.map(function (r) {
            return r.name === name ? { name: r.name, x: r.x, y: r.y, w: newW, h: newH } : r;
        });
        if (!anyOverlap(kept))
            next = kept;
    }
    var order = next.map(function (r) {
        var o = origin(r.name);
        var group = r.name === name ? 1 : (r.x > o.x || r.y > o.y ? 0 : 2);
        var key = group === 0 ? -(o.x + o.y) : (group === 2 ? o.x + o.y : 0);
        return { name: r.name, group: group, key: key };
    });
    order.sort(function (p, q) {
        return p.group - q.group || p.key - q.key;
    });
    return {
        rects: next,
        order: order.map(function (e) {
            return e.name;
        })
    };
}

// ---- Applying ----

function validMode(mode) {
    return /^(preferred|highres|highrr|\d+x\d+(@[0-9.]+)?)$/.test(String(mode));
}

function validPosition(pos) {
    return /^(auto(-(left|right|up|down))?|-?\d+x-?\d+)$/.test(String(pos));
}

function luaString(s) {
    return '"' + String(s).replace(/[\\"]/g, "\\$&") + '"';
}

// One hl.monitor({ ... }) call for an entry, or "" when a field is not safe to
// write into Lua. Entry: { output, disabled, mode, position, scale, transform,
// mirror }; unset fields are left out, which leaves them as they are.
function monitorCall(e) {
    if (!e || !SAFE_NAME.test(String(e.output || "")))
        return "";
    var parts = ["output = " + luaString(e.output)];
    if (e.disabled === true) {
        parts.push("disabled = true");
        return "hl.monitor({ " + parts.join(", ") + " })";
    }
    if (e.mode !== undefined && e.mode !== "") {
        if (!validMode(e.mode))
            return "";
        parts.push("mode = " + luaString(e.mode));
    }
    if (e.position !== undefined && e.position !== "") {
        if (!validPosition(e.position))
            return "";
        parts.push("position = " + luaString(e.position));
    }
    if (e.scale !== undefined && e.scale !== "" && e.scale !== null) {
        var s = Number(e.scale);
        if (!isFinite(s) || s <= 0)
            return "";
        parts.push("scale = " + String(s));
    }
    if (e.transform !== undefined && e.transform !== "" && e.transform !== null) {
        var t = Number(e.transform);
        if (!(t >= 0 && t <= 7) || Math.floor(t) !== t)
            return "";
        parts.push("transform = " + String(t));
    }
    if (e.mirror !== undefined && e.mirror !== "") {
        if (!SAFE_NAME.test(String(e.mirror)))
            return "";
        parts.push("mirror = " + luaString(e.mirror));
    }
    return "hl.monitor({ " + parts.join(", ") + " })";
}

// The expression for `hyprctl eval`: every entry in one go, so the displays
// never pass through a half-moved arrangement. "" when any entry is unsafe.
function buildEval(entries) {
    var calls = [];
    for (var i = 0; i < entries.length; i++) {
        var c = monitorCall(entries[i]);
        if (c === "")
            return "";
        calls.push(c);
    }
    return calls.join(" ");
}

function pos(x, y) {
    return Math.round(x) + "x" + Math.round(y);
}

// The entries that move displays to a layout: each at its place.
function layoutEntries(rects, order) {
    var byName = {};
    rects.forEach(function (r) {
        byName[r.name] = r;
    });
    var names = order && order.length ? order : rects.map(function (r) {
        return r.name;
    });
    return names.filter(function (n) {
        return byName[n];
    }).map(function (n) {
        return { output: n, position: pos(byName[n].x, byName[n].y) };
    });
}

// The change for a mode, scale or rotation on one display, with the others
// shifted around it in the same eval. `patch` may hold mode ("WxH@R"), scale
// and transform. Returns { entries, saves } where saves maps connector to the
// fields to remember. Alone, the display is placed by Hyprland ("auto").
function planChange(displays, name, patch) {
    var target = null;
    displays.forEach(function (d) {
        if (d.name === name)
            target = d;
    });
    if (!target)
        return { entries: [], saves: {} };
    var m = patch.mode ? /^(\d+)x(\d+)/.exec(patch.mode) : null;
    var width = m ? Number(m[1]) : target.width;
    var height = m ? Number(m[2]) : target.height;
    var scale = patch.scale !== undefined ? Number(patch.scale) : target.scale;
    if (m && patch.scale === undefined)
        scale = Number(cleanScale(target.scale, width, height)) || target.scale;
    var transform = patch.transform !== undefined ? patch.transform : target.transform;
    var mode = patch.mode || width + "x" + height + "@" + (Math.round(target.refreshRate * 100) / 100);
    var next = { name: name, width: width, height: height, scale: scale, transform: transform, x: target.x, y: target.y };
    var size = logicalRect(next);
    var layout = layoutDisplays(displays).map(logicalRect);
    var others = layout.filter(function (r) {
        return r.name !== name;
    });
    var saves = {};
    saves[name] = { mode: mode, scale: scale, transform: transform };
    var change = { output: name, mode: mode, scale: scale, transform: transform };
    if (others.length === 0 || !layout.some(function (r) {
        return r.name === name;
    })) {
        change.position = "auto";
        return { entries: [change], saves: saves };
    }
    var plan = resizeLayout(layout, name, size.w, size.h);
    var moved = layoutEntries(plan.rects, plan.order);
    var entries = moved.map(function (e) {
        if (e.output !== name)
            return e;
        change.position = e.position;
        return change;
    });
    plan.rects.forEach(function (r) {
        saves[r.name] = Object.assign(saves[r.name] || {}, { position: pos(r.x, r.y) });
    });
    return { entries: entries, saves: saves };
}

// ---- Brightness ----

// `ddcutil detect --brief` into { connector: i2c bus number }. Each block has
// an "I2C bus: /dev/i2c-N" line and a "DRM_connector: card1-DP-3" line.
function parseDdcDetect(text) {
    var out = {};
    var valid = false;
    var bus = null;
    String(text || "").split("\n").forEach(function (line) {
        var t = line.trim();
        if (/^(Display|Invalid display|Phantom display)\b/.test(t)) {
            valid = /^Display\b/.test(t);
            bus = null;
            return;
        }
        var b = /I2C bus:\s*\/dev\/i2c-(\d+)/.exec(t);
        if (b)
            bus = Number(b[1]);
        var c = /DRM_connector:\s*card\d+-(\S+)/.exec(t);
        if (c && valid && bus !== null && SAFE_NAME.test(c[1]))
            out[c[1]] = bus;
    });
    return out;
}

// `ddcutil getvcp 10 --terse` ("VCP 10 C 50 100") into a percent, or -1.
function parseVcp(text) {
    var m = /VCP\s+10\s+C\s+(\d+)\s+(\d+)/.exec(String(text || ""));
    if (!m || Number(m[2]) <= 0)
        return -1;
    return clampBrightness(Number(m[1]) * 100 / Number(m[2]));
}

// A backlight percent from `brightnessctl -m` ("dev,class,cur,50%,max"), or -1.
function backlightPercent(line) {
    var m = /,(\d+)%/.exec(String(line || ""));
    return m ? clampBrightness(Number(m[1])) : -1;
}

// ---- Saved settings ----
// One tab-separated line per display ever set, keyed by identity:
//   enabled  mode  position  scale  transform  mirror  identity
// `enabled` is "1", "0" or empty (never chosen); `mirror` is "internal" when
// the display mirrors the built-in panel. Any field may be empty. The Lua
// loader (modules/home/hyprland-monitor-settings.lua) reads the same format.

var FIELDS = ["enabled", "mode", "position", "scale", "transform", "mirror"];

function parseSettings(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var cols = line.split("\t");
        if (cols.length !== FIELDS.length + 1 || cols[FIELDS.length] === "")
            return;
        var row = {};
        FIELDS.forEach(function (f, i) {
            row[f] = cols[i];
        });
        out[cols[FIELDS.length]] = row;
    });
    return out;
}

function cell(v) {
    return v === undefined || v === null ? "" : String(v).replace(/[\t\n\r]/g, " ");
}

function serializeSettings(settings) {
    var lines = Object.keys(settings).sort().map(function (id) {
        var row = settings[id];
        return FIELDS.map(function (f) {
            return cell(row[f]);
        }).concat([cell(id)]).join("\t");
    });
    return lines.length ? lines.join("\n") + "\n" : "";
}

// A copy of `settings` with `patch` merged into the row of `identity`. enabled
// takes a boolean; the others their natural value.
function updateSetting(settings, identity, patch) {
    var out = {};
    Object.keys(settings).forEach(function (k) {
        out[k] = Object.assign({}, settings[k]);
    });
    var row = out[identity] || {};
    Object.keys(patch).forEach(function (k) {
        var v = patch[k];
        row[k] = k === "enabled" && typeof v === "boolean" ? (v ? "1" : "0") : cell(v);
    });
    FIELDS.forEach(function (f) {
        if (row[f] === undefined)
            row[f] = "";
    });
    out[identity] = row;
    return out;
}

// Rows for a plan's saves, keyed by the displays' identities.
function applySaves(settings, displays, saves) {
    var out = settings;
    Object.keys(saves).forEach(function (name) {
        var d = displays.filter(function (x) {
            return x.name === name;
        })[0];
        if (d)
            out = updateSetting(out, d.identity, saves[name]);
    });
    return out;
}

if (typeof module !== "undefined")
    module.exports = {
        SCALE_PRESETS: SCALE_PRESETS,
        NUDGE_STEP: NUDGE_STEP,
        isInternal: isInternal,
        clampBrightness: clampBrightness,
        normalizeScale: normalizeScale,
        cleanScale: cleanScale,
        availableScales: availableScales,
        resolutionOptions: resolutionOptions,
        resolutionLabel: resolutionLabel,
        refreshOptions: refreshOptions,
        modeFor: modeFor,
        transformFor: transformFor,
        degreesOf: degreesOf,
        nextRotation: nextRotation,
        turnedSize: turnedSize,
        identityOf: identityOf,
        displayTitle: displayTitle,
        parseDisplays: parseDisplays,
        layoutDisplays: layoutDisplays,
        enabledCount: enabledCount,
        canMirror: canMirror,
        isMirrored: isMirrored,
        logicalRect: logicalRect,
        copyRects: copyRects,
        overlaps: overlaps,
        layoutBounds: layoutBounds,
        anyOverlap: anyOverlap,
        normalizeLayout: normalizeLayout,
        dropDisplay: dropDisplay,
        sameLayout: sameLayout,
        placeBeside: placeBeside,
        mirrorMatches: mirrorMatches,
        resizeLayout: resizeLayout,
        monitorCall: monitorCall,
        buildEval: buildEval,
        layoutEntries: layoutEntries,
        planChange: planChange,
        parseSettings: parseSettings,
        serializeSettings: serializeSettings,
        updateSetting: updateSetting,
        applySaves: applySaves,
        parseDdcDetect: parseDdcDetect,
        parseVcp: parseVcp,
        backlightPercent: backlightPercent
    };
