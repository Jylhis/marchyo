import qs.Ui
import qs.Commons
import qs.Services

// CPU utilisation, read from the shared SystemStats singleton (which owns the
// single /proc/stat sampler for both this widget and the MonitorPanel).
BarItem {
    id: root

    interactive: true
    text: "󰐰 " + SystemStats.cpuUsage
    reserveText: "󰐰 100"
    tooltipText: I18n.t("cpu.tooltip", SystemStats.cpuUsage)
    onClicked: PanelManager.toggle("monitor", root)
}
