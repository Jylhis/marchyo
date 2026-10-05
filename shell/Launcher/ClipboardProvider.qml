import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/Cliphist.js" as Cliphist

// Clipboard history over `cliphist list` (fed by the wl-paste watchers in
// modules/home/hyprland.nix). Rerun per activation is a refresh, not a poll;
// rows decode in Commons/Cliphist.js. Text rows paste their text; image rows
// show a thumbnail and paste the image; other binary rows are skipped. Rows
// keep cliphist's newest-first order; the query filters.
//
// Thumbnails: ResultsView asks for one per image row it instantiates (rows in
// view), and those decode one at a time with `cliphist decode <id>` into
// <Quickshell.cacheDir>/cliphist/<Cliphist.cacheName>. The cache is the
// shell's own, nothing watches it, and each decode prunes it to the
// `maxCached` most recently shown files.
Provider {
    id: root

    providerId: "clipboard"
    maxRows: 12
    showIcons: false
    compact: true
    highlight: false
    selectOnEmpty: true
    previews: true
    emptyText: "clipboard history is empty"

    readonly property int maxHistory: 500
    readonly property string cacheDir: Quickshell.cacheDir + "/cliphist"
    readonly property int maxCached: 48
    // Entries cliphist lists as larger than this are not decoded, and the
    // decode output is cut at the same bound.
    readonly property int maxPreviewBytes: 16 * 1024 * 1024

    property var items: []
    // Pending thumbnail decodes ({ key, id }) and the one in flight.
    property var queue: []
    property string decodingKey: ""

    results: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.items.length && out.length < root.maxRows; i++) {
            const it = root.items[i];
            if (q.length === 0 || Fuzzy.score(it.prepared, q) >= 0)
                out.push(it);
        }
        return out;
    }

    function rowFor(entry) {
        if (entry.image)
            return root.imageRowFor(entry);
        const text = entry.text;
        return {
            title: text,
            subtitle: "",
            prepared: Fuzzy.prepare(text),
            icon: "",
            score: 0,
            positions: [],
            activate: () => {
                Launcher.close();
                Launcher.pasteText(text);
            }
        };
    }

    function imageRowFor(entry) {
        const title = Cliphist.describeImage(entry.image);
        return {
            title: title,
            subtitle: "",
            prepared: Fuzzy.prepare(title),
            icon: "",
            score: 0,
            positions: [],
            preview: Cliphist.cacheName(entry.id, entry.image),
            entryId: entry.id,
            bytes: entry.image.bytes,
            activate: () => {
                Launcher.close();
                Launcher.pasteImage(entry.id, "image/" + entry.image.format);
            }
        };
    }

    function setPreview(key, source) {
        const next = Object.assign({}, root.previewSources);
        next[key] = source;
        root.previewSources = next;
    }

    function requestPreview(row) {
        const key = row.preview;
        if (!key || root.previewSources[key] !== undefined || key === root.decodingKey || root.queue.some(p => p.key === key))
            return;
        if (row.bytes > root.maxPreviewBytes) {
            root.setPreview(key, "");
            return;
        }
        root.queue = root.queue.concat({
            key: key,
            id: row.entryId
        });
        root.pump();
    }

    function pump() {
        if (decodeProc.running || root.decodingKey !== "" || root.queue.length === 0 || !root.active)
            return;
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        root.decodingKey = next.key;
        decodeProc.command = ["sh", "-c", root.decodeScript, Config.cliphist, root.cacheDir, next.id, next.key, String(root.maxPreviewBytes), String(root.maxCached)];
        decodeProc.running = true;
    }

    // argv: $0 cliphist, $1 cache dir, $2 entry id, $3 file name, $4 byte
    // bound, $5 files to keep. Works inside the cache dir with ./-relative
    // names only. Decodes to a .part file and renames, so a half-written
    // thumbnail is never shown; reuses an existing file; touches it so
    // pruning (newest `keep` by mtime) keeps what was shown last.
    readonly property string decodeScript: ["c=$0 id=$2 f=$3 max=$4 keep=$5", "mkdir -p -- \"$1\" && cd -- \"$1\" || exit 1", "if [ ! -s \"./$f\" ]; then", "  \"$c\" decode \"$id\" | head -c \"$max\" > \"./$f.part\" && [ -s \"./$f.part\" ] && mv -f -- \"./$f.part\" \"./$f\" || { rm -f -- \"./$f.part\"; exit 1; }", "fi", "touch -- \"./$f\"", "ls -t | tail -n +\"$((keep + 1))\" | while IFS= read -r old; do rm -f -- \"./$old\"; done"].join("\n")

    readonly property var decodeProc: Process {
        id: decodeProc
        onExited: (exitCode, exitStatus) => {
            const key = root.decodingKey;
            root.decodingKey = "";
            if (key !== "")
                root.setPreview(key, exitCode === 0 ? "file://" + encodeURI(root.cacheDir + "/" + key) : "");
            Qt.callLater(root.pump);
        }
    }

    readonly property var listProc: Process {
        id: listProc
        command: [Config.cliphist, "list"]
        stdout: SplitParser {
            onRead: line => {
                const parsed = Cliphist.parseLine(line);
                if (parsed && root.items.length < root.maxHistory)
                    root.items = root.items.concat(root.rowFor(parsed));
            }
        }
    }

    onActiveChanged: {
        root.queue = [];
        if (root.active) {
            // Pruning may have dropped files a past session showed, so
            // re-resolve thumbnails per activation (an existing file is a
            // cheap hit in decodeScript).
            root.previewSources = ({});
            root.items = [];
            listProc.running = false;
            listProc.running = true;
        }
    }
}
