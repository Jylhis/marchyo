import qs.Ui
import qs.Commons
import qs.Services

// Notification do-not-disturb indicator. DND is in-shell state (the shell owns
// notifications, mako is retired), so this binds straight to the shared
// NotificationState singleton and toggles it in-process. No makoctl probe, no
// marchyo subprocess, no poll timer.
BarItem {
    id: root

    interactive: true
    text: NotificationState.dnd ? "󰂛" : "󰂚"
    textColor: NotificationState.dnd ? Color.statusErr : Color.textMuted
    tooltipText: NotificationState.dnd ? "Do not disturb — click to show notifications" : "Notifications on — click to enable do-not-disturb"

    onClicked: NotificationState.toggleDnd()
}
