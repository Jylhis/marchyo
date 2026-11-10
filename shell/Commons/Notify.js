// Pure notification-stack decisions shared by Services/NotificationState.
//
// Same dual-citizenship arrangement as Format.js (see its header): QML imports
// this directly and ignores the CommonJS guard at the bottom, Node loads it as
// an ordinary module, so tests/shell/notify-test.js exercises every branch under
// `nix flake check` without a Qt platform plugin. Must stay pure: no Qt types,
// no globals, no I/O — the caller passes urgencies in and the clock in.
//
// Both functions exist because the two bugs they encode were invisible to the
// test suite: expiry deadlines used to live in the toast delegate (which the
// view destroys and rebuilds on every arrival, restarting the countdown), and
// the visible cap used to give up entirely once only critical toasts were left.

// Pick the toast to evict when the stack is over the cap. Prefer the oldest
// non-critical one; if everything left is critical, evict the oldest critical
// rather than giving up.
//
// Giving up is what the old code did, and critical toasts never expire on
// their own (notifTimeoutCritical = 0), so a flapping unit could stack
// unbounded cards
// past the bottom of the screen with nothing but the clearNotifications IPC to
// clear them. `entries` is newest-first, so the last element is the oldest.
function evictionIndex(entries, isCritical) {
    if (!entries || entries.length === 0)
        return -1;
    for (var i = entries.length - 1; i >= 0; i--) {
        if (!isCritical(entries[i]))
            return i;
    }
    return entries.length - 1;
}

// Split entries into the ones whose deadline has passed and the ones that stay.
// A deadline of 0 (or anything non-positive) means "never expires".
function partitionExpired(entries, now) {
    var expired = [];
    var kept = [];
    var list = entries || [];
    for (var i = 0; i < list.length; i++) {
        var deadline = list[i] ? list[i].deadline : 0;
        if (deadline > 0 && deadline <= now)
            expired.push(list[i]);
        else
            kept.push(list[i]);
    }
    return {
        expired: expired,
        kept: kept
    };
}

// Prepend a history record (newest-first), prune entries older than the
// retention window, and trim to the cap. History holds plain data snapshots,
// not live Notification objects — a dismissed/expired toast is destroyed by the
// server, so retaining the object would need a RetainableLock and risks a
// use-after-free (impasto issue #3). A snapshot has none of that and serializes
// to disk as-is. `maxAgeMs <= 0` disables the age window.
function addHistory(history, record, cap, now, maxAgeMs) {
    var list = [record].concat(history || []);
    if (maxAgeMs > 0)
        list = list.filter(function (e) {
            return e && (now - e.timeMs) < maxAgeMs;
        });
    if (cap > 0 && list.length > cap)
        list = list.slice(0, cap);
    return list;
}

// First per-sender rule matching a notification's appName or desktopEntry
// (freedesktop match keys), or null. Matching is case-insensitive and exact;
// first rule wins. The caller applies field defaults (show/save default on,
// bypassDnd off, overrideDuration -1 = none) so a partial rule only overrides
// what it names.
function matchRule(rules, appName, desktopEntry) {
    var list = rules || [];
    var an = (appName || "").toLowerCase();
    var de = (desktopEntry || "").toLowerCase();
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r)
            continue;
        var mName = r.appName ? r.appName.toLowerCase() === an : false;
        var mEntry = r.desktopEntry ? r.desktopEntry.toLowerCase() === de : false;
        if (mName || mEntry)
            return r;
    }
    return null;
}

// Number of unread history entries (drives the bar's unread badge).
function unreadCount(history) {
    var n = 0;
    var list = history || [];
    for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].unread)
            n++;
    return n;
}

// Verification codes. A shape alone is also an order number, a port or a year,
// so a code only counts when the sender's own words (any common language) sit
// next to it. ASCII words use \b; scripts without ASCII word boundaries are
// matched as plain substrings.
var CODE_WORDS = new RegExp("\\b(?:code|codes|otp|one[\\s-]?time|verification|verify|passcode|pin|2fa|" + "two[\\s-]factor|security key|confirm(?:ation)?|código|codigo|codice|kode|kod|koodi\\w*|tunnus|" + "bestätigung\\w*|sicherheitscode|vahvistus\\w*|verifica\\w*|vérification)\\b" + "|验证码|驗證碼|認証|코드|인증|код|пароль|رمز", "i");
var CODE_SHAPE = /(?:^|[^\w-])((?:[A-Za-z]-)?\d{2,4}[\s-]\d{2,5}|(?:[A-Za-z]-)?\d{4,8})(?![\w-])/g;
var CODE_ALNUM = /(?:^|[^\w-])([A-Z0-9]{5,8})(?![\w-])/g;
var NEAR_BEFORE = 24;
var NEAR_AFTER = 72;
var MAX_CODES = 3;
var MAX_TEXT = 4000;

function bounded(text) {
    var t = String(text === undefined || text === null ? "" : text);
    return t.length > MAX_TEXT ? t.slice(0, MAX_TEXT) : t;
}

// "Claude Code", "VS Code": a capitalised word before a capitalised "Code" is
// a product name, not a request for a code.
function isProductName(t, at, word) {
    if (word.toLowerCase() !== "code" || word[0] !== word[0].toUpperCase())
        return false;
    var before = t.slice(Math.max(0, at - 20), at).match(/([A-Za-z][\w.]*)\s+$/);
    if (!before || !/^([A-Z][a-z]+|[A-Z]{2,})$/.test(before[1]))
        return false;
    return !CODE_WORDS.test(before[1]);
}

function codeWindows(t) {
    var out = [];
    var re = new RegExp(CODE_WORDS.source, "gi");
    var m;
    while ((m = re.exec(t)) !== null) {
        if (!isProductName(t, m.index, m[0]))
            out.push([Math.max(0, m.index - NEAR_BEFORE), m.index + m[0].length + NEAR_AFTER]);
        if (re.lastIndex === m.index)
            re.lastIndex++;
    }
    return out.slice(0, MAX_CODES);
}

// Prices, percentages, durations and decimals are numbers, not codes.
function looksLikeQuantity(win, start, end) {
    var before = win.slice(Math.max(0, start - 2), start);
    var after = win.slice(end, end + 12);
    if (/[$€£¥]\s?$/.test(before))
        return true;
    if (/^\s?(?:[$€£¥%]|eur\b|usd\b|gbp\b|sek\b|kr\b|min\b|mins\b|minutes?\b|seconds?\b|secs?\b|h\b|hours?\b|ms\b|[kmg]b\b|km\b|kg\b)/i.test(after))
        return true;
    if (/^[.,]\d/.test(after) || /\d[.,]$/.test(before))
        return true;
    return false;
}

function harvest(win, re, seen, out, keep) {
    var m;
    re.lastIndex = 0;
    while ((m = re.exec(win)) !== null) {
        var start = m.index + m[0].indexOf(m[1]);
        if (looksLikeQuantity(win, start, start + m[1].length))
            continue;
        var value = keep(m[1]);
        if (!value || seen[value])
            continue;
        seen[value] = true;
        out.push(value);
    }
}

// Verification codes in `text`, best first, at most MAX_CODES.
function detectCodes(text) {
    var t = bounded(text);
    var spans = codeWindows(t);
    if (spans.length === 0)
        return [];
    var out = [];
    var seen = {};
    var i;
    for (i = 0; i < spans.length; i++)
        harvest(t.slice(spans[i][0], spans[i][1]), CODE_SHAPE, seen, out, function (raw) {
            var value = raw.replace(/^[A-Za-z]-/, "").replace(/[\s-]/g, "");
            if (value.length < 4 || value.length > 8)
                return "";
            if (/^(19|20)\d\d$/.test(value))
                return "";
            return value;
        });
    if (out.length > 0)
        return out.slice(0, MAX_CODES);
    for (i = 0; i < spans.length; i++)
        harvest(t.slice(spans[i][0], spans[i][1]), CODE_ALNUM, seen, out, function (raw) {
            return (/\d/.test(raw) && /[A-Z]/.test(raw)) ? raw : "";
        });
    return out.slice(0, MAX_CODES);
}

// http(s) links in `text`, trailing sentence punctuation removed.
function detectLinks(text) {
    var out = [];
    var seen = {};
    var re = /(https?:\/\/[^\s<>"']+)/g;
    var t = bounded(text);
    var m;
    while ((m = re.exec(t)) !== null) {
        var url = m[1].replace(/[.,;:!?)\]}'"]+$/, "");
        if (url.length < 10 || seen[url])
            continue;
        seen[url] = true;
        out.push(url);
    }
    return out.slice(0, MAX_CODES);
}

var BROWSER = /(chrom|firefox|brave|vivaldi|opera|msedge|microsoft-edge|zen|librewolf|waterfox|floorp|epiphany)/i;

function hintString(hints, name) {
    var v = hints ? hints[name] : undefined;
    return typeof v === "string" ? v : "";
}

function hostOf(text) {
    var m = String(text || "").match(/(?:https?:\/\/)?(?:www\.)?([a-z0-9-]+(?:\.[a-z0-9-]+)+)/i);
    return m ? m[1].toLowerCase() : "";
}

// Deck key: browser notifications group per site (from the origin hint, a link
// or a bare host line in the body), everything else per application.
function deckKey(rec) {
    var app = String(rec.desktopEntry || rec.appName || "").toLowerCase().replace(/\.desktop$/, "");
    if (BROWSER.test(app) || BROWSER.test(String(rec.appName || ""))) {
        var site = hostOf(hintString(rec.hints, "x-kde-origin-name")) || hostOf(hintString(rec.hints, "x-kde-origin"));
        if (!site) {
            var links = detectLinks(rec.body);
            site = links.length > 0 ? hostOf(links[0]) : "";
        }
        if (!site) {
            var lines = String(rec.body || "").split("\n");
            site = hostOf(lines[lines.length - 1].replace(/<[^>]*>/g, "").trim());
        }
        if (site)
            return "site:" + site;
    }
    return "app:" + (app || "?");
}

// Rows are newest-first; returns decks in order of their newest row. With
// `stack` false every row is its own deck.
function buildDecks(rows, stack) {
    var order = [];
    var byKey = {};
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        var key = stack === false ? "row:" + i : deckKey(list[i]);
        if (!byKey[key]) {
            byKey[key] = {
                key: key,
                rows: []
            };
            order.push(key);
        }
        byKey[key].rows.push(list[i]);
    }
    return order.map(function (k) {
        return byKey[k];
    });
}

// Index of the visible row identical to `rec` (same app, summary and body), or -1.
function findRepeat(rows, rec) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (r.appName === rec.appName && r.summary === rec.summary && r.body === rec.body)
            return i;
    }
    return -1;
}

// Why a notification passes do-not-disturb, or "" when it is held back.
// Critical urgency, a per-sender rule, marchyo-action (`marchyo notify`'s
// default sender), an allow-listed app and a detected verification code all
// pass.
function dndPass(rec, opts) {
    var o = opts || {};
    var app = String(rec.appName || "").toLowerCase();
    var apps = o.passApps || [];
    if (rec.critical)
        return "critical";
    if (o.bypassRule)
        return "rule";
    if (app === "marchyo-action")
        return "app";
    for (var i = 0; i < apps.length; i++)
        if (String(apps[i]).toLowerCase() === app)
            return "app";
    if (o.detectCodes !== false && detectCodes(String(rec.summary || "") + "\n" + String(rec.body || "")).length > 0)
        return "code";
    return "";
}

// Window to raise for a notification: by pid when the sender gave one, else by
// window class against the desktop entry or app name. Returns an address or "".
function focusTarget(clients, rec) {
    var list = clients || [];
    var pid = Number(rec.pid) || 0;
    var names = [];
    var entry = String(rec.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
    if (entry) {
        names.push(entry);
        names.push(entry.split(".").pop());
    }
    if (rec.appName)
        names.push(String(rec.appName).toLowerCase());
    var i;
    if (pid > 0)
        for (i = 0; i < list.length; i++)
            if (list[i].pid === pid)
                return list[i].address || "";
    for (i = 0; i < list.length; i++) {
        var cls = String(list[i].class || list[i].initialClass || "").toLowerCase();
        if (cls && names.indexOf(cls) >= 0)
            return list[i].address || "";
    }
    return "";
}

// Click routing: the default action, then the sender's window, then the first
// link. `focusAddress` is the focusTarget result.
function routeClick(opts) {
    if (opts.hasDefault)
        return {
            step: "default",
            arg: ""
        };
    if (opts.focusAddress)
        return {
            step: "focus",
            arg: opts.focusAddress
        };
    if (opts.link)
        return {
            step: "link",
            arg: opts.link
        };
    return {
        step: "dismiss",
        arg: ""
    };
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        detectCodes: detectCodes,
        detectLinks: detectLinks,
        deckKey: deckKey,
        buildDecks: buildDecks,
        findRepeat: findRepeat,
        dndPass: dndPass,
        focusTarget: focusTarget,
        routeClick: routeClick,
        evictionIndex: evictionIndex,
        partitionExpired: partitionExpired,
        addHistory: addHistory,
        unreadCount: unreadCount,
        matchRule: matchRule
    };
