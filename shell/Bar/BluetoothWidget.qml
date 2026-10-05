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
    textColor: (adapter && adapter.enabled) ? Color.text : Color.textFaint
    tooltipText: {
        if (!adapter || !adapter.enabled)
            return "Bluetooth off";
        if (connected.length === 0)
            return "No devices connected";
        return "Devices connected: " + connected.length + "\n" + connected.join("\n");
    }

    onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.bluetui", "-e", Config.bluetui])
}
