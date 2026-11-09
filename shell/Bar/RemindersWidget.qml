import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Reminders indicator: a pure view over Services/Reminders, which owns the one
// timer probe for the seat.
BarItem {
    id: root

    interactive: true
    shown: true
    text: "󰢌 " + Reminders.count
    textColor: Colors.accent
    tooltipText: I18n.tn("reminders.pending", Reminders.count, Reminders.count)
    onClicked: PanelManager.toggle("reminders", root)
}
