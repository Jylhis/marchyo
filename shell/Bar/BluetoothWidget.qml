import Quickshell
import qs.Ui
import qs.Commons
import qs.Services

// Bluetooth status: a pure view over Services/BluetoothState, formatted to
// match waybar.
BarItem {
    id: root

    readonly property var adapter: BluetoothState.adapter
    readonly property var connected: BluetoothState.connected

    shown: BluetoothState.available
    interactive: true
    compact: true
    text: !adapter || !adapter.enabled ? "󰂲" : (connected.length > 0 ? "󰂯 " + connected.length : "󰂯")
    textColor: (adapter && adapter.enabled) ? Colors.text : Colors.textFaint
    tooltipText: {
        if (!adapter || !adapter.enabled)
            return I18n.t("bluetooth.off");
        if (connected.length === 0)
            return I18n.t("bluetooth.noDevices");
        return I18n.t("bluetooth.connected", connected.length) + "\n" + connected.join("\n");
    }

    onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.bluetui", "-e", Config.bluetui])
}
