import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Pure native binding on ToplevelManager.activeToplevel (no process, no timer),
// so it stays a safe per-monitor view per the Bar/ contract.
BarItem {
    id: root

    readonly property var active: ToplevelManager.activeToplevel
    readonly property string title: active ? (active.title || active.appId || "") : ""

    shown: root.title !== ""
    elide: true
    text: root.title
    textColor: Color.textMuted
    tooltipText: root.title
}
