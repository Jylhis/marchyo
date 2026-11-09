import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Health.js" as HealthJs

// Health indicator: a pure view over Services/Health (`marchyo doctor --json`).
// Hidden while every check passes; red with the failing checks in the tooltip
// otherwise. A click opens `marchyo doctor` in a terminal. Registered but not
// placed by default: add marchyo.health to a bar section.
BarItem {
    id: root

    interactive: true
    compact: true
    shown: Health.failed.length > 0
    text: "󰀦"
    textColor: Colors.statusErr
    tooltipText: I18n.tn("health.failing", Health.failed.length, Health.failed.length) + "\n" + HealthJs.summarizeChecks(Health.failed)

    onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.terminal", "-e", Config.bash, "-c", Config.marchyo + " doctor; read -rn1 -p 'Press any key'"])
}
