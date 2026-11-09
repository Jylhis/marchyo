pragma Singleton
import QtQuick
import QtQml
import Quickshell.Io
import qs.Commons

// Caps Lock / Num Lock state from the keyboard LED class devices
// (/sys/class/leds/<input>::capslock|numlock/brightness, world-readable and
// root-owned). Hyprland emits no IPC event on a lock-key toggle and sysfs LED
// attributes raise no inotify event, so non-consuming Caps_Lock / Num_Lock
// binds (modules/home/hyprland.nix) fire the `marchyo:lockKeys` global
// shortcut, which calls refresh(). A 10s reconcile re-reads the LEDs and
// re-lists them for hotplugged keyboards. All of it runs only while a
// LockKeysWidget exists: each widget calls acquire() / release(). A lock
// counts as on when any keyboard's LED is lit.
QtObject {
    id: root

    property bool capsLock: false
    property bool numLock: false

    property int _users: 0
    property var _capsPaths: []
    property var _numPaths: []

    function acquire(): void {
        root._users++;
    }

    function release(): void {
        root._users = Math.max(0, root._users - 1);
    }

    function anyLit(inst): bool {
        for (let i = 0; i < inst.count; i++) {
            const f = inst.objectAt(i);
            if (!f)
                continue;
            f.reload();
            if (parseInt(f.text(), 10) > 0)
                return true;
        }
        return false;
    }

    readonly property var list: Process {
        id: list
        command: [Config.ls, "/sys/class/leds"]
        stdout: StdioCollector {
            readonly property int maxChars: 64 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                const caps = [];
                const num = [];
                const names = text.split("\n");
                for (let i = 0; i < names.length; i++) {
                    const n = names[i].trim();
                    if (n.endsWith("::capslock"))
                        caps.push("/sys/class/leds/" + n + "/brightness");
                    else if (n.endsWith("::numlock"))
                        num.push("/sys/class/leds/" + n + "/brightness");
                }
                if (caps.join() !== root._capsPaths.join())
                    root._capsPaths = caps;
                if (num.join() !== root._numPaths.join())
                    root._numPaths = num;
            }
        }
    }

    readonly property var capsViews: Instantiator {
        id: capsViews
        model: root._capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
        onObjectAdded: root.refresh()
    }

    readonly property var numViews: Instantiator {
        id: numViews
        model: root._numPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
        onObjectAdded: root.refresh()
    }

    // The lock-key binds fire on key release, after the kernel has set the
    // LED; the short delay covers a keyboard whose LED write lands late.
    function refresh(): void {
        if (root._users > 0)
            settle.restart();
    }

    function read(): void {
        root.capsLock = root.anyLit(capsViews);
        root.numLock = root.anyLit(numViews);
    }

    readonly property var settle: Timer {
        id: settle
        interval: 50
        onTriggered: root.read()
    }

    // Slow reconcile: re-lists the LEDs (hotplugged keyboards) and catches a
    // lock change no bind saw (a remapped key, another keyboard's modifiers).
    readonly property var reconcile: Timer {
        interval: 10000
        running: root._users > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!list.running)
                list.running = true;
            root.read();
        }
        onRunningChanged: {
            if (!running) {
                root.capsLock = false;
                root.numLock = false;
            }
        }
    }
}
