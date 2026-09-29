pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons
import "../Commons/Notify.js" as Notify

// Shared notification state: single source of truth for do-not-disturb and the
// live toast list. DndWidget and the notification server both read/write this,
// so DND is in-process (no makoctl, no poll). Kept in qs.Services, deliberately
// separate from the Quickshell NotificationServer object (in qs.Notifications)
// to avoid a qs.Bar -> qs.Notifications import cycle.
//
// Expiry lives here, not in the toast delegate: `popups` is a value model, so
// every add/remove rebuilds all Repeater delegates in NotificationList.qml. A
// per-delegate expiry Timer would restart its countdown on each rebuild, so
// under a steady trickle older toasts never expired. One sweep timer over
// deadlines recorded at admission time is immune to view rebuilds.
QtObject {
    id: root

    // Do-not-disturb. While on, incoming non-critical notifications are held in
    // `queued` (no toast) and flushed back when DND clears (mako's
    // mode=do-not-disturb "invisible" semantics). Critical always show.
    property bool dnd: false

    // Visible toasts as { n, deadline } records, newest first. `deadline` is an
    // epoch-ms timestamp, or 0 for "never expires" (critical, per
    // Style.notifTimeoutCritical).
    property var entries: []

    // Notification objects for the view. Derived so `entries` is the only writer.
    readonly property var popups: root.entries.map(e => e.n)

    // Notifications held back by DND. Plain JS array of Notification objects.
    property var queued: []

    // Persistent history: immutable data snapshots (not live Notification
    // objects, see Notify.addHistory), newest-first. Every notification is
    // snapshotted on arrival, so a dismissed or DND-missed toast stays
    // recoverable from the notification centre.
    property var history: []
    property int seq: 0
    readonly property int historyCap: 100
    // Retention window: entries older than this are pruned on the next arrival.
    readonly property int historyMaxAgeMs: 7 * 24 * 3600 * 1000

    // Unread count for the bar's badge; only opening the notification centre
    // (markAllRead) marks entries read, not dismissing a toast.
    readonly property int unreadCount: Notify.unreadCount(root.history)

    // Snapshot a notification into history on arrival. Kept as plain data so it
    // outlives the destroyed Notification object and serializes to disk as-is.
    function record(n) {
        const rec = {
            "id": ++root.seq,
            "appName": n.appName || "",
            "appIcon": n.appIcon || "",
            "summary": n.summary || "",
            "body": n.body || "",
            "image": n.image || "",
            "urgency": n.urgency,
            "timeMs": Date.now(),
            "unread": true
        };
        root.history = Notify.addHistory(root.history, rec, root.historyCap, rec.timeMs, root.historyMaxAgeMs);
    }

    function markAllRead() {
        root.history = root.history.map(e => Object.assign({}, e, {
                "unread": false
            }));
    }

    function removeHistory(id) {
        root.history = root.history.filter(e => e.id !== id);
    }

    function clearHistory() {
        root.history = [];
    }

    // Persistence: history serializes to a state file across restarts. The shell
    // is the file's only writer, so watchChanges is false (read-once pattern).
    // Saves are debounced and atomic.

    // Gate saves until the initial disk read completes, so the empty startup
    // state never clobbers the file before it has been loaded.
    property bool historyLoaded: false

    function loadFromDisk(text) {
        try {
            const parsed = JSON.parse(text);
            if (Array.isArray(parsed)) {
                root.history = parsed;
                // Resume the id sequence past the highest restored id.
                let max = 0;
                for (let i = 0; i < parsed.length; i++)
                    if (parsed[i] && parsed[i].id > max)
                        max = parsed[i].id;
                root.seq = max;
            }
        } catch (e) {
            // Corrupt or empty file: start clean rather than crash.
        }
        root.historyLoaded = true;
    }

    onHistoryChanged: {
        if (root.historyLoaded)
            saveTimer.restart();
    }

    readonly property var historyFile: FileView {
        id: historyFile
        path: Quickshell.statePath("notification-history.json")
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.loadFromDisk(text())
        onLoadFailed: root.historyLoaded = true
    }

    // Coalesce a burst of arrivals / dismissals into one write.
    readonly property var saveTimer: Timer {
        interval: 1000
        onTriggered: historyFile.setText(JSON.stringify(root.history))
    }

    // Cap on notifications held while DND is on, bounding memory and the flood
    // when DND clears. Oldest beyond the cap are dismissed outright (mako simply
    // never shows them).
    readonly property int maxQueued: 20

    // Honour the sender's timeout when positive (expireTimeout is in seconds),
    // else the per-urgency default. 0 = never (critical persist until acted on).
    function timeoutMsFor(n) {
        if (!n)
            return Style.notifTimeoutNormal;
        if (n.expireTimeout > 0)
            return Math.round(n.expireTimeout * 1000);
        if (n.urgency === NotificationUrgency.Critical)
            return Style.notifTimeoutCritical;
        if (n.urgency === NotificationUrgency.Low)
            return Style.notifTimeoutLow;
        return Style.notifTimeoutNormal;
    }

    // Add a notification to the visible stack, or hold it under DND. Enforces the
    // visible cap, preferring to drop non-critical toasts. Every notification is
    // snapshotted into history first, so DND-suppressed and evicted toasts are
    // still recoverable from the notification centre.
    function show(n) {
        // Per-sender rules (Style.notifRules, baked from marchyo.notifications
        // .rules): a partial rule only overrides what it names.
        const rule = Notify.matchRule(Style.notifRules, n.appName, n.desktopEntry) || {};
        const saveHistory = rule.saveHistory !== false;
        const showToast = rule.showToast !== false;
        const bypassDnd = rule.bypassDnd === true;
        const override = (rule.overrideDuration !== undefined && rule.overrideDuration >= 0) ? rule.overrideDuration : -1;

        if (saveHistory)
            root.record(n);

        if (root.dnd && !bypassDnd && n.urgency !== NotificationUrgency.Critical) {
            let q = [n].concat(root.queued);
            // `queued` is newest-first; the oldest sit at the end. Dismiss the
            // overflow so it disappears at the sender too (never re-shown).
            while (q.length > root.maxQueued) {
                const drop = q.pop();
                drop.dismiss();
            }
            root.queued = q;
            return;
        }

        // A rule may keep a sender in history but suppress its toast entirely.
        if (!showToast) {
            n.dismiss();
            return;
        }
        root.present(n, override);
    }

    // Insert into the visible toast stack, enforcing the visible cap. Split from
    // show() so the DND flush can re-present already-recorded notifications
    // without snapshotting them into history a second time. `override` is a
    // per-rule duration in ms, or -1 for the sender/urgency default.
    function present(n, override) {
        const timeout = (override >= 0) ? override : root.timeoutMsFor(n);
        let list = [
            {
                "n": n,
                "deadline": timeout > 0 ? Date.now() + timeout : 0
            }
        ].concat(root.entries);
        let toDrop = [];
        const isCritical = e => e.n.urgency === NotificationUrgency.Critical;
        while (list.length > Style.notifMaxVisible) {
            const idx = Notify.evictionIndex(list, isCritical);
            if (idx < 0)
                break;
            toDrop.push(list[idx].n);
            list.splice(idx, 1);
        }
        root.entries = list;
        // Dismiss after reassigning so the `closed` -> remove() reentry is a no-op.
        for (let j = 0; j < toDrop.length; j++)
            toDrop[j].dismiss();
    }

    // Drop every toast whose deadline has passed, and expire it at the sender.
    function sweep() {
        const split = Notify.partitionExpired(root.entries, Date.now());
        if (split.expired.length === 0)
            return;
        // Reassign before expire() so the `closed` -> remove() reentry is a no-op.
        root.entries = split.kept;
        for (let i = 0; i < split.expired.length; i++)
            split.expired[i].n.expire();
    }

    // One sweep for the whole stack, running only while something can expire.
    readonly property var expiryTimer: Timer {
        interval: 500
        repeat: true
        running: root.entries.some(e => e.deadline > 0)
        onTriggered: root.sweep()
    }

    function remove(n) {
        root.entries = root.entries.filter(e => e.n !== n);
        root.queued = root.queued.filter(x => x !== n);
    }

    function setDnd(v) {
        if (root.dnd === v)
            return;
        root.dnd = v;
        if (!v && root.queued.length > 0) {
            const q = root.queued;
            root.queued = [];
            // Oldest first so the newest held notification ends up on top.
            // present(), not show(): they are already in history.
            for (let i = q.length - 1; i >= 0; i--)
                root.present(q[i], -1);
        }
    }

    function toggleDnd() {
        root.setDnd(!root.dnd);
    }

    // Dismiss the single newest notification (mako's `makoctl dismiss`, bound to
    // SUPER+comma). Prefers the newest on-screen toast; falls back to the newest
    // DND-queued one when nothing is visible. Both lists are newest-first, so
    // index 0 is the most recent. Reassign via remove() before dismiss() so the
    // `closed` -> remove() reentry is a no-op (matching clearAll's ordering).
    function dismissLast() {
        let n = null;
        if (root.entries.length > 0)
            n = root.entries[0].n;
        else if (root.queued.length > 0)
            n = root.queued[0];
        if (n === null)
            return;
        root.remove(n);
        n.dismiss();
    }

    function clearAll() {
        const all = root.popups.concat(root.queued);
        root.entries = [];
        root.queued = [];
        for (let i = 0; i < all.length; i++)
            all[i].dismiss();
    }
}
