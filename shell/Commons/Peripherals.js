// Pure parser for `solaar show` output, shared by Services/Peripherals.
//
// Same dual-citizenship arrangement as Format.js/Notify.js (see their headers):
// QML imports this directly and ignores the CommonJS guard at the bottom, Node
// loads it as an ordinary module, so tests/shell/peripherals-test.js exercises
// the parser under `nix flake check` without a Qt platform plugin. Must stay
// pure: no Qt types, no globals, no I/O — the caller passes the text in.
//
// It exists because the fallback path only fires for a Logitech receiver the
// kernel will not bind (so UPower never sees it), which means it can never be
// exercised on the build machine — the parser has to be provable headless.

// Parse the human-readable `solaar show` dump into [{name, pct}] for every
// paired device that reports a battery level. Devices are introduced by an
// "  N: Name" header; a later "Battery: NN%" (or "Battery level: NN%") line
// under that header carries the charge. A device with no battery line is
// skipped (a wired receiver, an unpaired slot).
function parseSolaarShow(text) {
    var out = [];
    var lines = (text || "").split("\n");
    var current = null;
    var headerRe = /^\s*\d+:\s+(.+?)\s*$/;
    var batteryRe = /Battery(?:\s+level)?\s*:\s*(\d+)\s*%/i;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var h = headerRe.exec(line);
        if (h) {
            current = {
                name: h[1],
                pct: -1
            };
            continue;
        }
        if (current && current.pct < 0) {
            var b = batteryRe.exec(line);
            if (b) {
                current.pct = parseInt(b[1], 10);
                out.push(current);
                current = null;
            }
        }
    }
    return out;
}

// Node (tests) picks this up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        parseSolaarShow: parseSolaarShow
    };
