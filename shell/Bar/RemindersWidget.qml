import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Reminders indicator: a pure view over Services/Reminders, which owns the one
// timer probe for the seat. Self-hiding when nothing is pending. Informational
// (marchyo has no interactive reminder GUI to click into); the tooltip carries
// the count. Ported from omarchy's Reminder indicator.
BarItem {
    id: root

    visible: Reminders.count > 0
    text: "󰢌 " + Reminders.count
    textColor: Color.accent
    tooltipText: Reminders.count === 1 ? "1 reminder pending" : Reminders.count + " reminders pending"
}
