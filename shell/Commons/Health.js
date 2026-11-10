// Pure parsers behind the bar's status indicators: pending update, free disk
// space and `marchyo doctor` health. Each takes the text of
// one probe and returns a small plain object, so the Services singletons stay
// thin and the logic is testable headlessly (see Format.js for why).

// `df -kP <path>` -> {freePercent, availKb} or null on anything unexpected.
function parseDf(text) {
    var lines = String(text || "").trim().split("\n");
    if (lines.length < 2)
        return null;
    var f = lines[lines.length - 1].trim().split(/\s+/);
    var used = parseInt(f[2], 10);
    var avail = parseInt(f[3], 10);
    if (!(used >= 0) || !(avail >= 0) || used + avail === 0)
        return null;
    return {freePercent: Math.round(avail / (used + avail) * 100), availKb: avail};
}

// Warn when free space is at or below the threshold percentage.
function diskLow(df, warnPercent) {
    return df !== null && df.freePercent <= warnPercent;
}

function formatKb(kb) {
    var gb = kb / 1048576;
    return gb >= 10 ? Math.round(gb) + " GiB" : gb.toFixed(1) + " GiB";
}

// `marchyo doctor --json` -> {failed: [check], warned: [check]}; unparsable
// output reports nothing rather than a false alarm.
function parseDoctor(text) {
    var data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return {failed: [], warned: []};
    }
    var checks = data && Array.isArray(data.checks) ? data.checks : [];
    return {
        failed: checks.filter(function (c) {
            return c && c.status === "fail";
        }),
        warned: checks.filter(function (c) {
            return c && c.status === "warn";
        })
    };
}

// `marchyo update --check --json` -> {available, locked, running}.
function parseUpdateCheck(text) {
    var data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return {available: false, locked: "", running: ""};
    }
    var d = data || {};
    return {
        available: d.available === true,
        locked: typeof d.locked === "string" ? d.locked : "",
        running: typeof d.running === "string" ? d.running : ""
    };
}

// One line per failing check, for a tooltip: "name: detail".
function summarizeChecks(checks) {
    return checks.map(function (c) {
        return c.name + ": " + c.detail;
    }).join("\n");
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        parseDf: parseDf,
        diskLow: diskLow,
        formatKb: formatKb,
        parseDoctor: parseDoctor,
        parseUpdateCheck: parseUpdateCheck,
        summarizeChecks: summarizeChecks
    };
