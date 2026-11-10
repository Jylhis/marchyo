// Pure helpers for the dev sandbox hooks (Services/Dev): the output override,
// the opt-in flags, and the geometry reported by the dev IPC target.
//
// Dual citizenship like Format.js: QML imports this directly and ignores the
// CommonJS guard, while Node loads it in tests/shell/dev-tools-test.js. Stay
// pure (no Qt types, no I/O) and never add a `.pragma` directive.

// MARCHYO_SHELL_OUTPUT: the override when an output of that name exists, else
// the output the caller would have used.
function pickOutput(override, names, fallback) {
    if (override && names.indexOf(override) >= 0)
        return override;
    return fallback;
}

function flagOn(value) {
    return value === "1";
}

// Top-left of a layer-shell window in output-local logical coordinates.
// `anchors` and `margins` are {left, right, top, bottom}; an axis anchored on
// both edges fills the output, an unanchored axis centers. `reserved` is the
// compositor's [left, top, right, bottom] exclusive area, which shrinks the
// output for every window that does not ignore exclusive zones.
function windowOrigin(anchors, margins, win, screen, reserved) {
    const r = reserved || [0, 0, 0, 0];
    return {
        x: r[0] + axisOrigin(anchors.left, anchors.right, margins.left, margins.right, win.width, screen.width - r[0] - r[2]),
        y: r[1] + axisOrigin(anchors.top, anchors.bottom, margins.top, margins.bottom, win.height, screen.height - r[1] - r[3])
    };
}

function axisOrigin(near, far, nearMargin, farMargin, size, total) {
    if (near)
        return nearMargin;
    if (far)
        return total - size - farMargin;
    return Math.round((total - size) / 2);
}

// Entry: {output, origin: {x, y}, offset: {x, y}, width, height} where offset
// is the card's position inside its window. Returns the name -> rect map.
function describe(entries) {
    const out = {};
    for (const name of Object.keys(entries)) {
        const e = entries[name];
        out[name] = {
            output: e.output,
            x: Math.round(e.origin.x + e.offset.x),
            y: Math.round(e.origin.y + e.offset.y),
            width: Math.round(e.width),
            height: Math.round(e.height)
        };
    }
    return out;
}

// Settled approximation: the quiet period since the last state change has
// elapsed and enough frames have rendered since it.
function isSettled(quiet, framesSince, minFrames) {
    return quiet && framesSince >= minFrames;
}

if (typeof module !== "undefined")
    module.exports = {
        pickOutput: pickOutput,
        flagOn: flagOn,
        windowOrigin: windowOrigin,
        describe: describe,
        isSettled: isSettled
    };
