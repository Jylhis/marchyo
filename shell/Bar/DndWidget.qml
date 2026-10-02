import qs.Ui
import qs.Commons
import qs.Services

// Notification do-not-disturb indicator + unread badge. The shell owns
// notifications in-process, so this binds straight to the shared
// NotificationState singleton: no external probe, subprocess, or poll timer.
BarItem {
    id: root

    interactive: true
    compact: true
    text: (NotificationState.dnd ? "󰂛" : "󰂚") + (NotificationState.unreadCount > 0 ? " " + NotificationState.unreadCount : "")
    textColor: NotificationState.dnd ? Color.statusErr : (NotificationState.unreadCount > 0 ? Color.text : Color.textMuted)
    tooltipText: (NotificationState.dnd ? "Do not disturb — left-click to show notifications" : "Notifications on — left-click to enable do-not-disturb") + "\nRight-click for history"

    onClicked: NotificationState.toggleDnd()
    onRightClicked: PanelManager.toggle("notifications", root)
}
