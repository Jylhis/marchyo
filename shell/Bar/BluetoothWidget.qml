import Quickshell
import Quickshell.Bluetooth
import qs.Ui
import qs.Commons

// Bluetooth status via the native BlueZ binding, formatted to match waybar.
BarItem {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connected: {
        const out = [];
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < devs.length; i++)
            if (devs[i].connected)
                out.push(devs[i].name || devs[i].address);
        return out;
    }

    shown: adapter !== null
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
