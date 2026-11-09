pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons
import "../Commons/Notify.js" as Notify
import "../Commons/NotificationCard.js" as NotificationCard
import "../Commons/notify/Store.js" as Store
import "../Commons/notify/Security.js" as Security

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

    // Visible toasts as { n, deadline, count, row } records, newest first.
    // `deadline` is an epoch-ms timestamp, or 0 for "never expires" (critical,
    // per Style.notifTimeoutCritical). `row` is the Store.snapshot of `n`: the
    // vetted exec command and buttons, glyph and transient flag.
    property var entries: []

    // Notification objects for the view. Derived so `entries` is the only writer.
    readonly property var popups: root.entries.map(e => e.n)

    // Plain-data view of a notification for the pure helpers in Notify.js.
    function recOf(n) {
        const hints = n.hints || {};
        return {
            "appName": n.appName || "",
            "desktopEntry": n.desktopEntry || "",
            "summary": n.summary || "",
            "body": n.body || "",
            "hints": hints,
            "pid": hints["sender-pid"] || 0,
            "critical": n.urgency === NotificationUrgency.Critical
        };
    }

    // Visible rows grouped into decks by sender (see Notify.buildDecks).
    readonly property var decks: Notify.buildDecks(root.entries.map(e => Object.assign(root.recOf(e.n), {
            "n": e.n,
            "count": e.count
        })), Style.notifStackBySender)

    // Display order of the toasts (deck by deck): what the keyboard walks.
    readonly property var flat: root.decks.reduce((acc, d) => acc.concat(d.rows.map(r => r.n)), [])

    // Verification codes in a notification, empty when detection is off.
    function codesOf(n) {
        return Style.notifDetectCodes ? Notify.detectCodes((n.summary || "") + "\n" + (n.body || "")) : [];
    }

    // Notifications held back by DND, newest first, as { n, row } records so the
    // vetted row (the one-time token is spent by then) survives the hold.
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
    // A transient notification is not kept, and a verification code is stored
    // as a placeholder (Store.sanitiseForPersistence), never as the code.
    function record(n, row, silenced) {
        if (row.transient)
            return 0;
        const safe = Store.sanitiseForPersistence(row);
        const rec = {
            "id": ++root.seq,
            "appName": safe.app,
            "desktopEntry": n.desktopEntry || "",
            "appIcon": n.appIcon || "",
            "summary": safe.summary,
            "body": safe.body,
            "image": "",
            "urgency": n.urgency,
            "timeMs": Date.now(),
            "unread": true,
            "silenced": silenced === true
        };
        root.history = Notify.addHistory(root.history, rec, root.historyCap, rec.timeMs, root.historyMaxAgeMs);
        return rec.id;
    }

    // An in-place update (replaces_id) rewrites the history entry the same way.
    function updateHistory(row) {
        if (!row.hid)
            return;
        if (row.transient) {
            root.removeHistory(row.hid);
            return;
        }
        const safe = Store.sanitiseForPersistence(row);
        root.history = root.history.map(e => e.id !== row.hid ? e : Object.assign({}, e, {
                "appName": safe.app,
                "summary": safe.summary,
                "body": safe.body
            }));
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

        const row = root.snapshotOf(n);
        root.watch(n);
        const pass = Notify.dndPass(root.recOf(n), {
            "passApps": Style.notifPassApps,
            "bypassRule": bypassDnd,
            "detectCodes": Style.notifDetectCodes
        });
        const silenced = root.dnd && pass === "";
        row.hid = saveHistory ? root.record(n, row, silenced) : 0;

        if (silenced) {
            // Nobody looks back at a transient notification; do not hold it.
            if (row.transient) {
                n.dismiss();
                return;
            }
            let q = [
                {
                    "n": n,
                    "row": row
                }
            ].concat(root.queued);
            // `queued` is newest-first; the oldest sit at the end. Dismiss the
            // overflow so it disappears at the sender too (never re-shown).
            while (q.length > root.maxQueued) {
                const drop = q.pop();
                drop.n.dismiss();
            }
            root.queued = q;
            return;
        }

        // A rule may keep a sender in history but suppress its toast entirely.
        if (!showToast) {
            n.dismiss();
            return;
        }
        root.present(n, override, row);
    }

    // Insert into the visible toast stack, enforcing the visible cap. Split from
    // show() so the DND flush can re-present already-recorded notifications
    // without snapshotting them into history a second time. `override` is a
    // per-rule duration in ms, or -1 for the sender/urgency default.
    function present(n, override, snapshot) {
        const row = snapshot || root.snapshotOf(n);
        const timeout = (override >= 0) ? override : root.timeoutMsFor(n);
        // An identical visible toast is replaced by this one with a higher count.
        let base = root.entries;
        let toDrop = [];
        let count = 1;
        const same = Notify.findRepeat(base.map(e => root.recOf(e.n)), root.recOf(n));
        if (same >= 0 && base[same].n !== n) {
            count = base[same].count + 1;
            toDrop.push(base[same].n);
            base = base.filter((e, i) => i !== same);
        }
        let list = [
            {
                "n": n,
                "deadline": timeout > 0 ? Date.now() + timeout : 0,
                "count": count,
                "row": row
            }
        ].concat(base);
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

    function pauseExpiry(n, paused) {
        const entry = root.entries.find(e => e.n === n);
        if (entry)
            NotificationCard.pauseExpiry(entry, paused, Date.now());
    }

    // Drop every toast whose deadline has passed, and expire it at the sender.
    function sweep() {
        if (root.kbActive)
            return;
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
        running: root.entries.some(e => e.deadline > 0 || e.remaining > 0)
        onTriggered: root.sweep()
    }

    // Exec safety. A notification may carry a click command, up to three
    // buttons and a glyph (the marchyo-exec-argv, marchyo-actions and
    // marchyo-glyph hints that `marchyo notify` sets). Any client on the session
    // bus can set a hint, so they are honoured only when the hint marchyo-token
    // is a one-time nonce that `marchyo notify` wrote to
    // $XDG_RUNTIME_DIR/marchyo/notify-nonce/<nonce> (mode 0600, same user only).
    // The check spends the nonce: it is remembered here and its file is removed,
    // so a nonce seen on the bus or in busctl's argv cannot be replayed. The
    // command is a vetted argv array (Security.parseExecArgv) that
    // Quickshell.execDetached runs without a shell; nothing from a
    // notification's summary or body is ever part of it.
    property string nonceDir: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR");
        return dir ? dir + "/marchyo/notify-nonce" : "";
    }

    // Spent nonces, oldest first. The file is removed too; this list covers the
    // moment before the removal lands.
    property var spentNonces: []
    readonly property int maxSpentNonces: 512

    readonly property var tokenFile: FileView {
        blockLoading: true
        blockAllReads: true
        watchChanges: false
        printErrors: false
    }

    // True when `hints` carries a nonce `marchyo notify` wrote and that nobody
    // has used yet. A true answer uses it up.
    function tokenOk(hints) {
        const given = hints ? hints["marchyo-token"] : undefined;
        if (typeof given !== "string" || !/^[0-9a-f]{64}$/.test(given) || root.nonceDir === "")
            return false;
        if (root.spentNonces.indexOf(given) >= 0)
            return false;
        const path = root.nonceDir + "/" + given;
        let have = "";
        try {
            root.tokenFile.path = path;
            root.tokenFile.reload();
            have = root.tokenFile.text().trim();
        } catch (e) {
            return false;
        }
        if (have !== given)
            return false;
        root.spentNonces = root.spentNonces.concat([given]).slice(-root.maxSpentNonces);
        Quickshell.execDetached([Config.rm, "-f", "--", path]);
        return true;
    }

    // True when the hints name something only `marchyo notify` may set.
    function wantsTrust(hints) {
        return !!hints && (hints["marchyo-exec-argv"] !== undefined || hints["marchyo-actions"] !== undefined || hints["marchyo-glyph"] !== undefined);
    }

    // The vetted row for a notification: exec command, buttons and glyph only
    // when the sender proved itself, text and the transient flag.
    function snapshotOf(n) {
        const trusted = root.wantsTrust(n.hints) ? root.tokenOk(n.hints) : false;
        return Store.snapshot(n, "t" + Date.now().toString(36) + (root.rowSeq++).toString(36), NotificationUrgency, trusted);
    }

    property int rowSeq: 0

    // Quickshell applies a Notify call with replaces_id to the existing object,
    // from any sender and without a new `notification` signal. So the row is
    // recomputed on every change, which re-runs the token check: an update that
    // does not carry a fresh nonce loses the command and the glyph it inherited.
    // Several signals follow one update; a zero-interval timer folds them into
    // one pass, and every click settles pending updates first.
    property var stale: []

    function watch(n) {
        const touch = () => root.touch(n);
        for (const name of ["appName", "appIcon", "summary", "body", "urgency", "image", "hints", "actions"]) {
            const signal = n[name + "Changed"];
            if (signal && signal.connect)
                signal.connect(touch);
        }
    }

    function touch(n) {
        if (root.stale.indexOf(n) < 0)
            root.stale = root.stale.concat([n]);
        root.refreshTimer.restart();
    }

    readonly property var refreshTimer: Timer {
        interval: 0
        onTriggered: root.flushRefresh()
    }

    function flushRefresh() {
        root.refreshTimer.stop();
        const list = root.stale;
        root.stale = [];
        for (let i = 0; i < list.length; i++)
            root.refreshRow(list[i]);
    }

    // The same notification's row, rebuilt: what the update changed, and the
    // identity (key, history entry) the old row had.
    function carry(old, fresh) {
        return Object.assign({}, fresh, {
            "key": old.key,
            "ts": old.ts,
            "duration": old.duration,
            "restored": old.restored,
            "hid": old.hid
        });
    }

    function refreshRow(n) {
        const mine = e => e.n === n;
        if (!root.entries.some(mine) && !root.queued.some(mine))
            return;
        const fresh = root.snapshotOf(n);
        let changed = null;
        const next = e => {
            if (!mine(e))
                return e;
            const merged = root.carry(e.row, fresh);
            if (JSON.stringify(merged) === JSON.stringify(e.row))
                return e;
            changed = merged;
            return Object.assign({}, e, {
                "row": merged
            });
        };
        if (root.entries.some(mine))
            root.entries = root.entries.map(next);
        if (root.queued.some(mine))
            root.queued = root.queued.map(next);
        if (changed !== null)
            root.updateHistory(changed);
    }

    function rowOf(n) {
        const e = root.entries.find(x => x.n === n);
        return e ? e.row : null;
    }

    function execArgvOf(n) {
        const row = root.rowOf(n);
        return row ? Security.parseExecArgv(row.execArgv) : null;
    }

    function execActionsOf(n) {
        const row = root.rowOf(n);
        return (row ? Security.parseExecActions(row.execActions) : null) || [];
    }

    // The only place a notification-derived command is run.
    function runArgv(argv) {
        if (Array.isArray(argv) && argv.length > 0 && argv[0].charAt(0) !== "-")
            Quickshell.execDetached(argv);
    }

    // The buttons a toast offers beside its code buttons, in the order the number
    // keys count them: the sender's `--action` commands, then its own actions.
    function deedsOf(n) {
        if (!n)
            return [];
        const out = root.execActionsOf(n).map((a, i) => ({
                    "kind": "exec",
                    "index": i,
                    "label": a.label
                }));
        for (const a of root.keyActions(n))
            out.push({
                "kind": "action",
                "action": a,
                "label": a.text
            });
        return out;
    }

    function invokeDeed(n, deed) {
        root.flushRefresh();
        if (deed.kind === "exec") {
            // The button the user saw must still be the one at this index.
            const a = root.execActionsOf(n)[deed.index];
            if (a && a.label === deed.label)
                root.runArgv(a.argv);
            root.remove(n);
            n.dismiss();
            return;
        }
        deed.action.invoke();
        if (!n.resident)
            root.remove(n);
    }

    // Live toasts survive a shell restart (notification-live.json, restored with
    // a short grace; critical ones wait for the user). Transient rows never
    // persist, and codes are stored as placeholders by Store.persistable.
    property bool liveLoaded: false

    function saveLive() {
        if (!root.liveLoaded)
            return;
        const rows = root.entries.filter(e => e.row && !e.row.transient).map(e => Store.persistable(e.row));
        liveFile.setText(Store.serialise(rows.reverse()));
    }

    onEntriesChanged: liveTimer.restart()

    readonly property var liveTimer: Timer {
        interval: 400
        onTriggered: root.saveLive()
    }

    function restoreLive(text) {
        const rows = Store.parseLive(text);
        // Oldest first, so the newest ends on top. They are already in history,
        // and Do Not Disturb held them back or let them through before.
        for (let i = 0; i < rows.length; i++) {
            const row = Store.restored(rows[i]);
            if (!row)
                continue;
            const ghost = ghostComponent.createObject(root, {
                "appName": row.app,
                "appIcon": row.appIcon,
                "summary": row.summary,
                "body": row.body,
                "urgency": row.urgency,
                "hints": row.senderPid > 0 ? {
                    "sender-pid": row.senderPid
                } : {}
            });
            if (ghost)
                root.present(ghost, row.duration, row);
        }
        root.liveLoaded = true;
    }

    readonly property var ghostComponent: Component {
        GhostNotification {}
    }

    readonly property var liveFile: FileView {
        id: liveFile
        path: Quickshell.statePath("notification-live.json")
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.restoreLive(text())
        onLoadFailed: root.liveLoaded = true
    }

    // Do Not Disturb survives a restart too (notification-quiet.json).
    property bool quietLoaded: false

    readonly property var quietFile: FileView {
        id: quietFile
        path: Quickshell.statePath("notification-quiet.json")
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            const q = Store.parseQuiet(text());
            if (q && q.dnd)
                root.dnd = true;
            root.quietLoaded = true;
        }
        onLoadFailed: root.quietLoaded = true
    }

    onDndChanged: {
        if (root.quietLoaded)
            quietFile.setText(Store.serialiseQuiet({
                "dnd": root.dnd
            }));
    }

    function remove(n) {
        root.entries = root.entries.filter(e => e.n !== n);
        root.queued = root.queued.filter(x => x.n !== n);
        if (root.entries.length === 0)
            root.stopKeyboard();
        else if (root.kbIndex >= root.entries.length)
            root.kbIndex = root.entries.length - 1;
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
                root.present(q[i].n, -1, q[i].row);
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
            n = root.queued[0].n;
        if (n === null)
            return;
        root.remove(n);
        n.dismiss();
    }

    // Keyboard control. Notifications never take the keyboard on their own: a
    // toast grabbing focus as it arrived would swallow what you were typing.
    // `startKeyboard` (the SUPER+ALT+comma bind) selects the newest toast and
    // hands the stack the keyboard until a choice is made, Escape is pressed,
    // or kbIdleMs pass without a key. Toast expiry pauses meanwhile.
    property bool kbActive: false
    property int kbIndex: 0
    readonly property int kbIdleMs: 10000

    readonly property var kbIdleTimer: Timer {
        interval: root.kbIdleMs
        onTriggered: root.stopKeyboard()
    }

    // The buttons a toast offers, in the order the number keys count them. The
    // implicit "default" action belongs to the card body (Enter), not a button.
    function keyActions(n) {
        return n ? n.actions.filter(a => a.identifier !== "default") : [];
    }

    function startKeyboard() {
        if (root.entries.length === 0)
            return;
        root.kbIndex = 0;
        root.kbActive = true;
        root.kbIdleTimer.restart();
    }

    function stopKeyboard() {
        root.kbActive = false;
        root.kbIdleTimer.stop();
    }

    function moveSelection(delta) {
        if (!root.kbActive || root.entries.length === 0)
            return;
        root.kbIndex = Math.max(0, Math.min(root.flat.length - 1, root.kbIndex + delta));
        root.kbIdleTimer.restart();
    }

    function selectedNotification() {
        return root.kbActive && root.kbIndex < root.flat.length ? root.flat[root.kbIndex] : null;
    }

    function dismissSelected() {
        const n = root.selectedNotification();
        if (n === null)
            return;
        root.remove(n);
        n.dismiss();
    }

    // Press the nth (1-based) button of the selected toast, then hand the
    // keyboard back like a mouse click on that button does.
    function invokeSelectedAction(nth) {
        root.flushRefresh();
        const n = root.selectedNotification();
        const list = root.deedsOf(n);
        if (n === null || nth < 1 || nth > list.length)
            return;
        root.invokeDeed(n, list[nth - 1]);
        root.stopKeyboard();
    }

    // Click the selected card: run its default action if any, then dismiss.
    function activateSelected() {
        const n = root.selectedNotification();
        if (n === null)
            return;
        root.activate(n);
        root.stopKeyboard();
    }

    // Click routing (Notify.routeClick): the default action, else the sender's
    // window, else the first link. The toast is dismissed in every case.
    property var routePending: null

    function hasDefault(n) {
        return n.actions.some(a => a.identifier === "default");
    }

    function activate(n) {
        root.flushRefresh();
        // The sender's own click command (vetted, see tokenOk) comes first.
        const argv = root.execArgvOf(n);
        if (argv !== null) {
            root.runArgv(argv);
            root.remove(n);
            n.dismiss();
            return;
        }
        const link = Notify.detectLinks((n.summary || "") + "\n" + (n.body || ""))[0] || "";
        if (root.hasDefault(n)) {
            n.actions.find(a => a.identifier === "default").invoke();
        } else {
            root.routePending = {
                "rec": root.recOf(n),
                "link": link
            };
            clientsProc.running = true;
        }
        root.remove(n);
        n.dismiss();
    }

    function finishRoute(clients) {
        const p = root.routePending;
        root.routePending = null;
        if (!p)
            return;
        const step = Notify.routeClick({
            "hasDefault": false,
            "focusAddress": Notify.focusTarget(clients, p.rec),
            "link": p.link
        });
        if (step.step === "focus" && /^0x[0-9a-f]+$/i.test(step.arg)) {
            focusProc.command = [Config.hyprctl, "dispatch", "focuswindow", "address:" + step.arg];
            focusProc.running = true;
        } else if (step.step === "link") {
            Security.openExternalUrl(step.arg);
        }
    }

    // Enter on a notification-centre row: its first link, else the sender's
    // window. A stored row has no live sender, so it never runs a command.
    function activateHistory(entry) {
        const link = Security.safeHttpUrl(Notify.detectLinks(entry.body || "")[0] || "");
        root.routePending = {
            "rec": {
                "appName": entry.appName || "",
                "desktopEntry": entry.desktopEntry || "",
                "pid": 0
            },
            "link": link
        };
        clientsProc.running = true;
    }

    readonly property var clientsProc: Process {
        id: clientsProc
        command: [Config.hyprctl, "clients", "-j"]
        stdout: StdioCollector {
            id: clientsOut
        }
        onExited: {
            let clients = [];
            try {
                clients = JSON.parse(clientsOut.text);
            } catch (e) {
                // No compositor answer: fall through to the link step.
            }
            root.finishRoute(Array.isArray(clients) ? clients : []);
        }
    }

    readonly property var focusProc: Process {
        id: focusProc
    }

    readonly property var copyProc: Process {
        id: copyProc
    }

    // Put a detected code on the clipboard. Only short alphanumerics pass, so
    // nothing but a code can reach the argv.
    function copyCode(code) {
        if (!/^[A-Za-z0-9]{4,8}$/.test(code))
            return;
        copyProc.command = [Config.wlCopy, code];
        copyProc.running = true;
    }

    // IPC: act on the newest visible toast like a click on it. Returns "none"
    // when nothing is on screen.
    function actNewest() {
        if (root.entries.length === 0)
            return "none";
        root.activate(root.entries[0].n);
        return "ok";
    }

    // IPC: dismiss the newest visible toast only; returns how many remain.
    function dismissOne() {
        if (root.entries.length === 0)
            return "0";
        const n = root.entries[0].n;
        root.remove(n);
        n.dismiss();
        return String(root.entries.length);
    }

    function clearAll() {
        const all = root.popups.concat(root.queued.map(q => q.n));
        root.entries = [];
        root.queued = [];
        for (let i = 0; i < all.length; i++)
            all[i].dismiss();
    }
}
