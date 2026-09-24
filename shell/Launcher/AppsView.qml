import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import "../Commons/Match.js" as Match

// App search over Quickshell's DesktopEntries model (the same source of
// truth the app grid uses; marchyo's xdg.desktopEntries webapps flow in
// automatically). Pure view: the entry list is seat-global, scoring is the
// Node-tested Match.js, launching is DesktopEntry.execute().
//
// A query is matched against several desktop fields (name, generic name,
// keywords, comment, exec) with per-field penalties so a name hit always
// outranks a comment hit — the QsFlow / vicinae behaviour. Each desktop
// action (e.g. Firefox "New Private Window") is indexed as its own row while
// a query is present. Matched characters in the app name are highlighted, and
// `suggestion` exposes the top prefix match for the ghost-text autocomplete
// in LauncherWindow.
Item {
    id: root

    property string query: ""
    readonly property int maxResults: 8
    readonly property int rowHeight: Style.panelRowHeight

    readonly property var entries: DesktopEntries.applications.values

    // Per-field penalties subtracted from a field's raw match score. Name is
    // authoritative (0); the softer fields only surface an app that the name
    // alone would miss.
    readonly property int genericPenalty: 150
    readonly property int keywordPenalty: 200
    readonly property int commentPenalty: 300
    readonly property int execPenalty: 250
    readonly property int actionAppPenalty: 100

    // Best score across an entry's fields, plus the name-match positions (for
    // highlighting) when the name itself matched. Returns null on no match.
    function scoreEntry(entry, q) {
        const nameMatch = Match.match(entry.name, q);
        let best = nameMatch ? nameMatch.score : -1;
        const positions = nameMatch ? nameMatch.positions : [];

        const generic = Match.score(entry.genericName, q);
        if (generic >= 0)
            best = Math.max(best, generic - root.genericPenalty);

        const comment = Match.score(entry.comment, q);
        if (comment >= 0)
            best = Math.max(best, comment - root.commentPenalty);

        const exec = Math.max(Match.score(entry.execString, q), Match.score(entry.id, q));
        if (exec >= 0)
            best = Math.max(best, exec - root.execPenalty);

        const keywords = entry.keywords || [];
        for (let k = 0; k < keywords.length; k++) {
            const kw = Match.score(keywords[k], q);
            if (kw >= 0)
                best = Math.max(best, kw - root.keywordPenalty);
        }

        if (best < 0)
            return null;
        return {
            entry: entry,
            action: null,
            label: entry.name,
            positions: positions,
            score: best
        };
    }

    // Recomputed on query or entry-set change. noDisplay entries (hidden by
    // their own file) never show; an empty query lists names A→Z; a non-empty
    // query also folds in matching desktop actions.
    readonly property var matches: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            if (e.noDisplay)
                continue;

            const row = root.scoreEntry(e, q);
            if (row)
                out.push(row);

            if (q.length === 0)
                continue;

            const actions = e.actions || [];
            for (let a = 0; a < actions.length; a++) {
                const act = actions[a];
                const byAction = Match.score(act.name, q);
                const byName = Match.match(e.name, q);
                let best = byAction;
                if (byName && byName.score - root.actionAppPenalty > best)
                    best = byName.score - root.actionAppPenalty;
                if (best < 0)
                    continue;
                out.push({
                    entry: e,
                    action: act,
                    label: e.name,
                    actionName: act.name,
                    // Highlight the app name only when it (not the action
                    // text) is what matched, so positions stay aligned.
                    positions: byName ? byName.positions : [],
                    score: best
                });
            }
        }
        out.sort((a, b) => (b.score - a.score) || a.label.localeCompare(b.label));
        return out.slice(0, root.maxResults);
    }

    // The top result's full name when the current query is a prefix of it —
    // the completion LauncherWindow renders as dimmed ghost text and accepts
    // on Tab / Right. Empty for action rows and non-prefix matches.
    readonly property string suggestion: {
        const q = root.query.trim();
        if (q.length === 0 || root.matches.length === 0)
            return "";
        const top = root.matches[0];
        if (top.action)
            return "";
        return top.entry.name.toLowerCase().startsWith(q.toLowerCase()) ? top.entry.name : "";
    }

    implicitHeight: list.count > 0 ? list.implicitHeight : rowHeight

    ListView {
        id: list
        anchors.fill: parent
        spacing: Style.spacing
        clip: true
        model: root.matches
        currentIndex: root.query.trim().length > 0 ? 0 : -1

        delegate: Rectangle {
            id: delegate
            required property var modelData
            required property int index
            width: ListView.view.width
            height: root.rowHeight
            color: ListView.isCurrentItem ? Color.surfaceRaised : "transparent"
            border.width: ListView.isCurrentItem ? 1 : 0
            border.color: Color.accent

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.currentIndex = delegate.index;
                    root.activate();
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.margins: Style.paddingH
                spacing: Style.spacing

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Quickshell.iconPath(delegate.modelData.entry.icon)
                    sourceSize.width: Style.fontSize + 8
                    sourceSize.height: Style.fontSize + 8
                    visible: source.toString().length > 0
                }

                // App name with the matched characters coloured, followed by a
                // muted action label for action rows.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: {
                        const name = Match.highlight(delegate.modelData.label, delegate.modelData.positions, Color.accent.toString());
                        return delegate.modelData.action ? name + ' <font color="' + Color.textMuted.toString() + '">· ' + Match.escapeHtml(delegate.modelData.actionName) + "</font>" : name;
                    }
                    color: delegate.ListView.isCurrentItem ? Color.textHeading : Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    elide: Text.ElideRight
                    width: parent.parent.width - Style.paddingH * 4
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: "no matches"
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    function move(delta) {
        if (list.count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
    }

    function activate() {
        const m = root.matches[list.currentIndex];
        if (!m)
            return;
        Launcher.close();
        if (m.action)
            m.action.execute();
        else
            m.entry.execute();
    }
}
