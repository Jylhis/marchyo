// Pure per-monitor resolution of shell.json: the global config with an
// output's `monitors.<name>` override merged over it.
//
// shell.json carries one global config plus an optional `monitors` map keyed
// by output name (e.g. "DP-1"). Each entry overrides the global values for
// that output only. Keys in ALWAYS_GLOBAL are seat-wide (one idle timer and
// one inhibitor per seat), so a per-monitor value for them is ignored.
//
// Merge rules: plain objects merge key by key, recursively; arrays and
// scalars replace the global value whole (a per-monitor `bar.layout.right`
// is the complete right section for that output, not an append).
//
// Plain JavaScript with a CommonJS guard (no `.pragma`, see Format.js) so
// tests/shell/monitor-config-test.js covers it headlessly. Stays pure: no Qt
// types, no globals, no I/O. Inputs are never mutated.

// Top-level keys a per-monitor override cannot change.
var ALWAYS_GLOBAL = ["idle", "caffeine", "monitors"];

var SECTIONS = ["left", "center", "right"];

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Recursive merge of `over` onto `base` under the rules above. Returns a new
// object; non-object inputs yield `over` when defined, else `base`.
function deepMerge(base, over) {
    if (!isPlainObject(base) || !isPlainObject(over))
        return over === undefined ? base : over;
    const out = {};
    for (const k of Object.keys(base))
        out[k] = base[k];
    for (const k of Object.keys(over))
        out[k] = Object.prototype.hasOwnProperty.call(base, k) ? deepMerge(base[k], over[k]) : over[k];
    return out;
}

// The per-monitor override for `output`, minus the always-global keys.
// Returns {} when there is none (or it is malformed).
function overrideFor(config, output) {
    if (!isPlainObject(config) || !isPlainObject(config.monitors) || !output)
        return {};
    const raw = config.monitors[output];
    if (!isPlainObject(raw))
        return {};
    const out = {};
    for (const k of Object.keys(raw)) {
        if (ALWAYS_GLOBAL.indexOf(k) < 0)
            out[k] = raw[k];
    }
    return out;
}

// Effective config for `output`: global config with that output's override
// merged over it. The `monitors` map itself is not part of the result. An
// empty or unknown output resolves to the global config.
function resolve(config, output) {
    const base = {};
    if (isPlainObject(config)) {
        for (const k of Object.keys(config)) {
            if (k !== "monitors")
                base[k] = config[k];
        }
    }
    return deepMerge(base, overrideFor(config, output));
}

// Effective bar layout for `output`: { left, center, right }. Each section
// falls back independently to `defaults` when the resolved layout leaves it
// unset (or sets it to a non-array), so a partial override stays valid.
function barLayout(config, output, defaults) {
    const resolved = resolve(config, output);
    const bar = isPlainObject(resolved.bar) ? resolved.bar : {};
    const layout = isPlainObject(bar.layout) ? bar.layout : {};
    const fallback = isPlainObject(defaults) ? defaults : {};
    const out = {};
    for (const s of SECTIONS)
        out[s] = Array.isArray(layout[s]) ? layout[s] : (Array.isArray(fallback[s]) ? fallback[s] : []);
    return out;
}

// Bar styles the shell draws. The first is the default.
var BAR_STYLES = ["flat", "segmented"];

// Effective bar style for `output`: the resolved `bar.style` when it names a
// known style, else "flat". A per-monitor `bar.style` overrides the global one.
function barStyle(config, output) {
    const resolved = resolve(config, output);
    const style = isPlainObject(resolved.bar) ? resolved.bar.style : undefined;
    return BAR_STYLES.indexOf(style) >= 0 ? style : BAR_STYLES[0];
}

// CommonJS guard: QML ignores this, Node requires it (see format-test.js).
if (typeof module !== "undefined" && module.exports)
    module.exports = {
        ALWAYS_GLOBAL: ALWAYS_GLOBAL,
        deepMerge: deepMerge,
        overrideFor: overrideFor,
        resolve: resolve,
        barLayout: barLayout,
        BAR_STYLES: BAR_STYLES,
        barStyle: barStyle
    };
