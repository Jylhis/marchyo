import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// App search over Quickshell's DesktopEntries (seat-global; webapps flow in
// via xdg.desktopEntries). Scoring is Commons/Fuzzy (the Node-tested Match.js over fuzzysort): several
// desktop fields matched with per-field penalties so a name hit outranks a
// comment hit (vicinae behaviour). Desktop actions are indexed as their own
// rows while a query is present; `suggestion` feeds the query field's ghost
// text.
Provider {
    id: root

    providerId: "apps"
    completes: true

    readonly property int maxResults: 8

    readonly property var entries: DesktopEntries.applications.values

    // Per-field penalties subtracted from a field's raw match score. Name is
    // authoritative (0); the softer fields only surface an app that the name
    // alone would miss.
    readonly property int genericPenalty: 150
    readonly property int keywordPenalty: 200
    readonly property int commentPenalty: 300
    readonly property int execPenalty: 250
    readonly property int actionAppPenalty: 100

    function scoreEntry(entry, q) {
        const nameMatch = Fuzzy.match(entry.name, q);
        let best = nameMatch ? nameMatch.score : -1;
        const positions = nameMatch ? nameMatch.positions : [];

        const generic = Fuzzy.score(entry.genericName, q);
        if (generic >= 0)
            best = Math.max(best, generic - root.genericPenalty);

        const comment = Fuzzy.score(entry.comment, q);
        if (comment >= 0)
            best = Math.max(best, comment - root.commentPenalty);

        const exec = Math.max(Fuzzy.score(entry.execString, q), Fuzzy.score(entry.id, q));
        if (exec >= 0)
            best = Math.max(best, exec - root.execPenalty);

        const keywords = entry.keywords || [];
        for (let k = 0; k < keywords.length; k++) {
            const kw = Fuzzy.score(keywords[k], q);
            if (kw >= 0)
                best = Math.max(best, kw - root.keywordPenalty);
        }

        if (best < 0)
            return null;
        return root.row(entry, null, positions, best);
    }

    function row(entry, action, positions, score) {
        return {
            title: entry.name,
            subtitle: action ? action.name : "",
            isAction: action !== null,
            icon: entry.icon,
            score: score,
            positions: positions,
            activate: () => {
                Launcher.close();
                if (action)
                    action.execute();
                else
                    entry.execute();
            }
        };
    }

    results: {
        if (!root.active)
            return [];
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            if (e.noDisplay)
                continue;

            const r = root.scoreEntry(e, q);
            if (r)
                out.push(r);

            if (q.length === 0)
                continue;

            const actions = e.actions || [];
            for (let a = 0; a < actions.length; a++) {
                const act = actions[a];
                const byAction = Fuzzy.score(act.name, q);
                const byName = Fuzzy.match(e.name, q);
                let best = byAction;
                if (byName && byName.score - root.actionAppPenalty > best)
                    best = byName.score - root.actionAppPenalty;
                if (best < 0)
                    continue;
                // Highlight the app name only when it (not the action text)
                // is what matched, so positions stay aligned.
                out.push(root.row(e, act, byName ? byName.positions : [], best));
            }
        }
        out.sort((a, b) => (b.score - a.score) || a.title.localeCompare(b.title));
        return out.slice(0, root.maxResults);
    }

    // Top result's full name when the query is a prefix of it: the ghost-text
    // completion the query field accepts on Tab / Right. Empty otherwise.
    suggestion: {
        const q = root.query.trim();
        if (q.length === 0 || root.results.length === 0)
            return "";
        const top = root.results[0];
        if (top.isAction)
            return "";
        return top.title.toLowerCase().startsWith(q.toLowerCase()) ? top.title : "";
    }
}
