import qs.Ui
import qs.Commons
import qs.Services

// Notification do-not-disturb indicator + unread badge. DND is in-shell state
// (the shell owns notifications, mako is retired), so this binds straight to the
// shared NotificationState singleton and toggles it in-process. No makoctl
// probe, no marchyo subprocess, no poll timer. Left-click toggles DND;
// right-click opens the notification centre (history). A trailing count shows
// unread history entries.
BarItem {
    id: root

    interactive: true
    text: (NotificationState.dnd ? "󰂛" : "󰂚") + (NotificationState.unreadCount > 0 ? " " + NotificationState.unreadCount : "")
    textColor: NotificationState.dnd ? Color.statusErr : (NotificationState.unreadCount > 0 ? Color.text : Color.textMuted)
    tooltipText: (NotificationState.dnd ? "Do not disturb — left-click to show notifications" : "Notifications on — left-click to enable do-not-disturb") + "\nRight-click for history"

    onClicked: NotificationState.toggleDnd()
    onRightClicked: PanelManager.toggle("notifications", root)
}
