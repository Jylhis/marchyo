pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons

// Camera-in-use state for the camera privacy indicator, from two signals:
//
// 1. PipeWire (event-driven, no cost): a link group whose source is a
//    Video/Source node (a v4l2/libcamera camera, or a virtual camera) names the
//    consuming client directly. Link presence is the signal: a link group's
//    `state` reads Unlinked unless the group is bound by a PwObjectTracker.
// 2. Direct V4L2 opens (most browsers and conferencing apps open /dev/video*
//    themselves, bypassing PipeWire): a bounded `find` over /proc/<pid>/fd for
//    links to /dev/video*, then one `ps` for the holders' command names. The
//    scan runs on inotify open/close events on the /dev/video* nodes, plus a
//    60s reconcile (3s while the watcher is down), and only while PipeWire reports a camera node, so a host
//    without a camera never runs it. The PipeWire daemons are dropped from its
//    result: their opens are the PipeWire consumers already named by signal 1.
QtObject {
    id: root

    // Display names of the apps using a camera (deduplicated).
    readonly property var users: {
        const out = root.pipewireUsers.slice();
        for (let i = 0; i < root.deviceUsers.length; i++) {
            if (out.indexOf(root.deviceUsers[i]) < 0)
                out.push(root.deviceUsers[i]);
        }
        return out;
    }
    readonly property bool inUse: users.length > 0

    // A camera node exists; gates the /proc poll.
    readonly property bool present: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i] && !nodes[i].isStream && nodes[i].type === PwNodeType.VideoSource)
                return true;
        }
        return false;
    }

    // Consumer nodes linked to a Video/Source node.
    readonly property var consumers: {
        const out = [];
        const groups = Pipewire.linkGroups ? Pipewire.linkGroups.values : [];
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (g && g.source && g.target && g.source.type === PwNodeType.VideoSource && out.indexOf(g.target) < 0)
                out.push(g.target);
        }
        return out;
    }

    // Binding the consumers is what fills their `properties` (application.name).
    readonly property var tracker: PwObjectTracker {
        objects: root.consumers
    }

    readonly property var pipewireUsers: {
        const out = [];
        for (let i = 0; i < root.consumers.length; i++) {
            const name = root.nodeLabel(root.consumers[i]);
            if (out.indexOf(name) < 0)
                out.push(name);
        }
        return out;
    }

    // Names of processes holding /dev/video* open (excluding PipeWire).
    property var deviceUsers: []

    readonly property var daemons: ["pipewire", "wireplumber"]

    function nodeLabel(n): string {
        const p = n.properties || {};
        return p["application.name"] || n.description || n.nickname || n.name || "app";
    }

    // argv[0] basename, with a Nix wrapper's ".<name>-wrapped" unwrapped.
    function commandName(args): string {
        const argv0 = args.trim().split(/\s+/)[0] || "";
        const base = argv0.slice(argv0.lastIndexOf("/") + 1);
        const m = base.match(/^\.(.+)-wrapped$/);
        return m ? m[1] : base;
    }

    function setDeviceUsers(list): void {
        if (list.length === root.deviceUsers.length && list.every((v, i) => v === root.deviceUsers[i]))
            return;
        root.deviceUsers = list;
    }

    onPresentChanged: {
        if (!root.present)
            root.setDeviceUsers([]);
        else if (!devList.running)
            devList.running = true;
    }

    // Prunes every /proc/<pid>/* subtree except fd/, so it reads one fd table
    // per process and nothing else.
    readonly property var scan: Process {
        id: scan
        command: [Config.find, "/proc", "-maxdepth", "3", "(", "-path", "/proc/[0-9]*/fd/*", "-lname", "/dev/video*", "-printf", "%h\\n", ")", "-o", "(", "-path", "/proc/*/*", "-not", "-path", "/proc/[0-9]*/fd", "-prune", ")"]
        stdout: StdioCollector {
            readonly property int maxChars: 64 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                const pids = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^\/proc\/(\d+)\/fd$/);
                    if (m && pids.indexOf(m[1]) < 0)
                        pids.push(m[1]);
                }
                if (pids.length === 0) {
                    root.setDeviceUsers([]);
                    return;
                }
                names.command = [Config.ps, "-o", "args=", "-p", pids.join(",")];
                names.running = true;
            }
        }
    }

    readonly property var names: Process {
        id: names
        stdout: StdioCollector {
            readonly property int maxChars: 64 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const name = root.commandName(lines[i]);
                    if (name.length > 0 && root.daemons.indexOf(name) < 0 && out.indexOf(name) < 0)
                        out.push(name);
                }
                root.setDeviceUsers(out);
            }
        }
    }

    // /dev/video* nodes to watch, re-listed whenever PipeWire's camera set
    // changes (a hotplugged camera shows up there first).
    property var videoDevices: []

    readonly property int cameraNodes: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        let n = 0;
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i] && !nodes[i].isStream && nodes[i].type === PwNodeType.VideoSource)
                n++;
        }
        return n;
    }
    onCameraNodesChanged: {
        if (root.present && !devList.running)
            devList.running = true;
    }

    readonly property var devList: Process {
        id: devList
        command: [Config.ls, "/dev"]
        stdout: StdioCollector {
            readonly property int maxChars: 256 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                const out = text.split("\n").map(n => n.trim()).filter(n => /^video[0-9]+$/.test(n)).map(n => "/dev/" + n);
                if (out.join() !== root.videoDevices.join())
                    root.videoDevices = out;
            }
        }
    }

    // inotify open/close events on the camera nodes: an app that opens a
    // camera directly fires one, so the /proc scan runs on demand. The
    // watcher relaunches when the node list changes (a new command only
    // applies on launch) and restarts with backoff when it exits; while it
    // is down the reconcile below runs at the 3s polling cadence.
    readonly property bool wantWatch: root.present && root.videoDevices.length > 0
    readonly property bool watching: watcher.running
    property string watchArgs: ""
    property bool relaunch: false
    property int watchBackoff: 1000
    property real watchStarted: 0

    onWantWatchChanged: root.syncWatcher()
    onVideoDevicesChanged: root.syncWatcher()

    function syncWatcher(): void {
        if (!root.wantWatch) {
            watchRetry.stop();
            if (watcher.running)
                watcher.running = false;
            return;
        }
        const args = [Config.inotifywait, "-m", "-q", "-e", "open,close", "--format", "%e"].concat(root.videoDevices);
        if (watcher.running) {
            if (JSON.stringify(args) === root.watchArgs)
                return;
            root.relaunch = true;
            watcher.running = false;
            return;
        }
        root.watchArgs = JSON.stringify(args);
        watcher.command = args;
        root.watchStarted = Date.now();
        watcher.running = true;
    }

    readonly property var watcher: Process {
        id: watcher
        stdout: SplitParser {
            onRead: settle.restart()
        }
        onExited: {
            if (root.relaunch) {
                root.relaunch = false;
                root.syncWatcher();
                return;
            }
            if (!root.wantWatch)
                return;
            if (Date.now() - root.watchStarted > 30000)
                root.watchBackoff = 1000;
            watchRetry.interval = root.watchBackoff;
            watchRetry.restart();
            root.watchBackoff = Math.min(root.watchBackoff * 2, 60000);
            settle.restart();
        }
    }

    readonly property var watchRetry: Timer {
        id: watchRetry
        onTriggered: root.syncWatcher()
    }

    // Coalesces an open/close burst (PipeWire and the app each touch the
    // node) into one scan, and waits out a scan that is still running.
    readonly property var settle: Timer {
        id: settle
        interval: 300
        onTriggered: {
            if (scan.running || names.running)
                settle.restart();
            else
                scan.running = true;
        }
    }

    // Bounded reconcile for what inotify cannot see (a holder that opened the
    // node before the watcher started): every 60s while the watcher runs, at
    // the 3s polling cadence while it does not.
    readonly property var reconcile: Timer {
        interval: root.watching ? 60000 : 3000
        running: root.present
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!devList.running)
                devList.running = true;
            settle.restart();
        }
    }
}
