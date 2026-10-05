import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Caps Lock / Num Lock indicator: a pure view over Services/LockKeys, shown
// only while a lock is on. Registering with the service is what runs its
// poll, so the poll exists only while this widget is in a bar layout.
BarItem {
    readonly property var locks: {
        const out = [];
        if (LockKeys.capsLock)
            out.push("CAPS");
        if (LockKeys.numLock)
            out.push("NUM");
        return out;
    }

    shown: locks.length > 0
    text: locks.join(" ")
    textColor: Color.statusWarn
    tooltipText: locks.map(k => k === "CAPS" ? "Caps Lock on" : "Num Lock on").join("\n")

    Component.onCompleted: LockKeys.acquire()
    Component.onDestruction: LockKeys.release()
}
