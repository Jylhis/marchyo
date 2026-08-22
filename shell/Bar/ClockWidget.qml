import Quickshell
import qs.Ui

// Live clock. Mirrors waybar's format ("Sat 22 Aug · 14:30").
BarItem {
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
}
