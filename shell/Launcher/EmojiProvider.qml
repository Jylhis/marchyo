import QtQuick
import qs.Commons
import qs.Services
import "../Commons/EmojiData.js" as EmojiData

// Emoji picker: a grid over Commons/EmojiData.js (full catalog in the store
// shell, a dev subset from the tree), searched by name with Commons/Fuzzy in
// catalog order. Activating copies AND types the emoji at the cursor (vicinae
// parity); see Services/Launcher.pasteText.
Provider {
    id: root

    providerId: "emoji"
    layout: "grid"
    columns: 8
    showIcons: false
    emptyText: "no emoji"

    // One row per catalog entry, built once: the title is the emoji itself,
    // the subtitle its name (the searched field, prepared once for Fuzzy).
    readonly property var allRows: EmojiData.parse(EmojiData.RAW).map(e => ({
                title: e.chars,
                subtitle: e.name,
                prepared: Fuzzy.prepare(e.name),
                icon: "",
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    Launcher.pasteText(e.chars);
                }
            }))

    results: {
        if (!root.active)
            return [];
        const q = root.query.trim();
        if (q.length === 0)
            return root.allRows;
        return root.allRows.filter(r => Fuzzy.score(r.prepared, q) >= 0);
    }
}
