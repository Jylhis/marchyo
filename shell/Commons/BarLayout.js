// Pure layout decisions for the bar sections — which separators render.
//
// Why a .js module and not inline QML: the rules below exist because hidden
// widgets and orphaned rules between them are invisible to every other gate —
// `nix flake check` cannot start Quickshell, and the offscreen harness renders
// no real services. A plain JavaScript module has dual citizenship (QML
// imports it directly; Node loads it as an ordinary module), so every branch
// is unit-tested headlessly by tests/shell/bar-layout-test.js. Anything in
// here must stay pure: no Qt types, no globals, no I/O.
//
// Deliberately NOT a `.pragma library` module (a syntax error to Node); see
// Format.js for the full reasoning.

// The first-party separator entry id (ShellConfig layout data). Single
// source of truth for Commons/BarLayout.js and Ui/BarSection.qml; pinned to
// ShellConfig's default layout by tests/shell/contracts-test.sh.
var SEPARATOR_ID = "marchyo.separator";

// Decide which separator entries render, given a section's entry ids and each
// entry's effective visibility (separators themselves pass false — their
// rendering is what this function decides).
//
// Rules:
//   - a separator renders only with visible content on BOTH sides;
//   - when the widgets between two separators are all hidden (an empty
//     cluster), the run collapses to exactly one rendered rule: the first
//     separator of the run;
//   - leading/trailing separators of a section never render.
//
// Returns a boolean array parallel to `ids` (true = render). Defensive about
// missing/short `shown` input: anything not exactly true reads as hidden.
function separatorVisibility(ids, shown) {
    if (!Array.isArray(ids) || !Array.isArray(shown))
        return [];
    const count = Math.min(ids.length, shown.length);
    const result = new Array(ids.length).fill(false);
    let lastContent = -1;
    for (let k = 0; k < count; k++) {
        if (ids[k] === SEPARATOR_ID || !shown[k])
            continue;
        if (lastContent >= 0) {
            for (let s = lastContent + 1; s < k; s++) {
                if (ids[s] === SEPARATOR_ID) {
                    result[s] = true;
                    break;
                }
            }
        }
        lastContent = k;
    }
    return result;
}

// CommonJS guard: QML ignores this, Node requires it (see format-test.js).
if (typeof module !== "undefined" && module.exports)
    module.exports = {
        SEPARATOR_ID: SEPARATOR_ID,
        separatorVisibility: separatorVisibility
    };
