import qs.Ui
import qs.Commons
import qs.Services

// Notification bell: toggles do-not-disturb on click, shows the unread count,
// and opens the history on right-click. Binds straight to the shared
// NotificationState singleton: no external probe, subprocess, or poll timer.
BarIndicator {
    id: root

    interactive: true
    compact: true
    indicatorActive: NotificationState.dnd || NotificationState.unreadCount > 0
    text: (NotificationState.dnd ? "󰂛" : "󰂚") + (NotificationState.unreadCount > 0 ? " " + NotificationState.unreadCount : "")
    textColor: NotificationState.dnd ? Colors.statusErr : (NotificationState.unreadCount > 0 ? Colors.text : Colors.textMuted)
    tooltipText: I18n.t(NotificationState.dnd ? "notifications.dndOn" : "notifications.dndOff") + "\n" + I18n.t("notifications.historyHint")

    onClicked: NotificationState.toggleDnd()
    onRightClicked: PanelManager.toggle("notifications", root)
}
