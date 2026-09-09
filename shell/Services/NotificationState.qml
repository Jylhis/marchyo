pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import qs.Commons
import "../Commons/Notify.js" as Notify

// Shared notification state: the single source of truth for do-not-disturb and
// the live on-screen toast list. Both the bar's DndWidget and the notification
// server read/write this, so DND is in-process state (no makoctl, no poll) and
// the server, the popup stack, and the keybind IPC all agree. Kept in qs.Services
// like PanelManager, and deliberately separate from the Quickshell
// NotificationServer object (which lives in qs.Notifications) to avoid a
// qs.Bar -> qs.Notifications import cycle.
//
// Expiry lives here, not in the toast delegate. `popups` is a value model, so
// every add and remove makes the Repeater in Notifications/NotificationList.qml
// destroy and rebuild all of its delegates. When each delegate owned its own
// expiry Timer, that rebuild restarted the countdown: a toast shown at t=0 with
// a 5s timeout was rebuilt when the next one arrived at t=4s and then expired at
// t=9s, and again on the next arrival, so under a steady trickle older toasts
// never expired at all. One sweep timer over deadlines recorded at admission
// time is immune to how often the view is rebuilt.
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

    // The Notification objects themselves, for the view. Derived so `entries`
    // stays the only thing that is written.
    readonly property var popups: root.entries.map(e => e.n)

    // Notifications held back by DND. Plain JS array of Notification objects.
    property var queued: []

    // Cap on notifications held while DND is on: a long do-not-disturb stretch
    // must not accumulate an unbounded pile of tracked notifications (memory,
    // plus a toast flood the moment DND clears). Oldest beyond the cap are
    // dismissed outright — mako's behaviour is to simply not show them.
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
    // visible cap, preferring to drop non-critical toasts.
    function show(n) {
        if (root.dnd && n.urgency !== NotificationUrgency.Critical) {
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
        const timeout = root.timeoutMsFor(n);
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
            for (let i = q.length - 1; i >= 0; i--)
                root.show(q[i]);
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
