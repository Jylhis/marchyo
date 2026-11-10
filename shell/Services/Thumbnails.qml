pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/Appearance.js" as Appearance

// Cached picker thumbnails. request() hands image paths to the marchyo-thumbs
// script (Config.thumbs), which writes a thumbnail per image into
// $XDG_CACHE_HOME/marchyo/thumbs, keyed by path, size and mtime, and prints
// "image<TAB>thumbnail" lines as it goes. sourceFor() answers with the
// thumbnail once it exists and with the full image until then (or when the
// script is missing), so a picker always has something to draw.
QtObject {
    id: root

    // Longest edge of a generated thumbnail, in pixels.
    readonly property int size: 480

    // image path -> thumbnail path; replaced as a whole so bindings update.
    property var map: ({})

    property var wanted: []

    function sourceFor(path: string): string {
        if (path.length === 0)
            return "";
        const thumb = root.map[path];
        return "file://" + (thumb !== undefined ? thumb : path);
    }

    function request(paths: var): void {
        root.wanted = paths.filter(p => p.length > 0);
        if (!root.genProc.running)
            root.run();
    }

    function run(): void {
        if (root.wanted.length === 0)
            return;
        root.genProc.command = [Config.thumbs, String(root.size)].concat(root.wanted);
        root.wanted = [];
        root.genProc.running = true;
    }

    function take(line: string): void {
        const entry = Appearance.parseThumbLine(line);
        if (entry === null)
            return;
        const next = Object.assign({}, root.map);
        next[entry.path] = entry.thumb;
        root.map = next;
    }

    readonly property var genProc: Process {
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        onExited: root.run()
    }
}
