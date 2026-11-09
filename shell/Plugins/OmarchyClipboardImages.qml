import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/ClipboardImages.js" as ClipboardImages
import "../Commons/Paths.js" as Paths

// Removes the omarchy.clipboard images that its history no longer references
// (Commons/ClipboardImages.js), each time the plugin saves the history.
Item {
    id: root
    visible: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string historyPath: root.home + "/.local/state/omarchy/clipboard-history.json"
    readonly property string imageDir: Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), root.home, "/.local/state") + "/omarchy/clipboard-images"

    FileView {
        id: historyFile
        path: root.historyPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (text() === root.seen)
                return;
            root.seen = text();
            pruneTimer.restart();
        }
    }

    property string seen: ""

    // The plugin saves the history by rename, which ends the inotify watch.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: historyFile.reload()
    }

    Timer {
        id: pruneTimer
        interval: 2000
        onTriggered: {
            const keep = ClipboardImages.referencedImages(historyFile.text(), root.imageDir);
            if (keep === null || pruneProc.running)
                return;
            pruneProc.command = ClipboardImages.pruneArgv(Config.find, root.imageDir, keep);
            pruneProc.running = true;
        }
    }

    Process {
        id: pruneProc
    }
}
