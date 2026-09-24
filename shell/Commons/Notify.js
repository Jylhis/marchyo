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

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        evictionIndex: evictionIndex,
        partitionExpired: partitionExpired,
        addHistory: addHistory,
        unreadCount: unreadCount,
        matchRule: matchRule
    };
