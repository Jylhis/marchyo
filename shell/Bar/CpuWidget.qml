import qs.Ui
import qs.Services

// CPU utilisation, read from the shared SystemStats singleton (which owns the
// single /proc/stat sampler for both this widget and the MonitorPanel). Matches
// waybar's "cpu N%". Click opens the monitor panel (btop still one click away
// inside it).
BarItem {
    id: root

    interactive: true
    text: "󰐰 " + SystemStats.cpuUsage
    tooltipText: "CPU " + SystemStats.cpuUsage + "%"
    onClicked: PanelManager.toggle("monitor")
}
