pragma Singleton
import QtQuick
import QtQml
import Quickshell.Io
import qs.Commons

// Caps Lock / Num Lock state from the keyboard LED class devices
// (/sys/class/leds/<input>::capslock|numlock/brightness, world-readable and
// root-owned). Hyprland emits no IPC event on a lock-key toggle and sysfs LED
// attributes raise no inotify event, so this is a short poll of a few sysfs
// reads (no subprocess), run only while a LockKeysWidget exists: each widget
// calls acquire() / release(). A lock counts as on when any keyboard's LED is
// lit. The LED list is re-read on a slower cadence to pick up hotplugged
// keyboards.
QtObject {
    id: root

    property bool capsLock: false
    property bool numLock: false

    property int _users: 0
    property var _capsPaths: []
    property var _numPaths: []
    property int _ticks: 0

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
    }

    readonly property var numViews: Instantiator {
        id: numViews
        model: root._numPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
    }

    readonly property var poll: Timer {
        interval: 500
        running: root._users > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Re-list LEDs on the first tick and every 10 s after.
            if (root._ticks % 20 === 0 && !list.running)
                list.running = true;
            root._ticks++;
            root.capsLock = root.anyLit(capsViews);
            root.numLock = root.anyLit(numViews);
        }
        onRunningChanged: {
            if (!running) {
                root._ticks = 0;
                root.capsLock = false;
                root.numLock = false;
            }
        }
    }
}
