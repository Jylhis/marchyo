pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import qs.Commons

// Shared notification state: the single source of truth for do-not-disturb and
// the live on-screen toast list. Both the bar's DndWidget and the notification
// server read/write this, so DND is in-process state (no makoctl, no poll) and
// the server, the popup stack, and the keybind IPC all agree. Kept in qs.Services
// like PanelManager, and deliberately separate from the Quickshell
// NotificationServer object (which lives in qs.Notifications) to avoid a
// qs.Bar -> qs.Notifications import cycle.
QtObject {
    id: root

    // Do-not-disturb. While on, incoming non-critical notifications are held in
    // `queued` (no toast) and flushed back when DND clears (mako's
    // mode=do-not-disturb "invisible" semantics). Critical always show.
    property bool dnd: false

    // Notification objects currently shown as toasts (newest first) and those held
    // back by DND. Plain JS arrays so delegates read the Notification fields direct.
    property var popups: []
    property var queued: []

    // Cap on notifications held while DND is on: a long do-not-disturb stretch
    // must not accumulate an unbounded pile of tracked notifications (memory,
    // plus a toast flood the moment DND clears). Oldest beyond the cap are
    // dismissed outright — mako's behaviour is to simply not show them.
    readonly property int maxQueued: 20

    // Add a notification to the visible stack, or hold it under DND. Enforces the
    // visible cap by dismissing the oldest non-critical toasts beyond the limit.
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
        let list = [n].concat(root.popups);
        let toDrop = [];
        while (list.length > Style.notifMaxVisible) {
            let idx = -1;
            for (let i = list.length - 1; i >= 0; i--) {
                if (list[i].urgency !== NotificationUrgency.Critical) {
                    idx = i;
                    break;
                }
            }
            if (idx === -1)
                break; // everything left is critical, keep them all
            toDrop.push(list[idx]);
            list.splice(idx, 1);
        }
        root.popups = list;
        // Dismiss after reassigning so the `closed` -> remove() reentry is a no-op.
        for (let j = 0; j < toDrop.length; j++)
            toDrop[j].dismiss();
    }

    function remove(n) {
        root.popups = root.popups.filter(x => x !== n);
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

    function clearAll() {
        const all = root.popups.concat(root.queued);
        root.popups = [];
        root.queued = [];
        for (let i = 0; i < all.length; i++)
            all[i].dismiss();
    }
}
