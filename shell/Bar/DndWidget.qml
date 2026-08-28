import qs.Ui
import qs.Commons
import qs.Services

// Notification do-not-disturb indicator. DND is now in-shell state (the shell
// owns notifications, mako is retired), so this binds straight to the shared
// NotificationState singleton and toggles it in-process. No makoctl probe, no
// marchyo subprocess, no poll timer.
BarItem {
    id: root

    interactive: true
    text: NotificationState.dnd ? "dnd" : "notif"
    textColor: NotificationState.dnd ? Color.statusErr : Color.textMuted

    onClicked: NotificationState.toggleDnd()
}
