import Quickshell
import Quickshell.Bluetooth
import qs.Ui
import qs.Commons

// Bluetooth status via the native BlueZ binding. "bt off" when the adapter is
// disabled, "bt N" with a connected count, else "bt". Matches waybar's format.
// Click opens bluetui in a floating terminal; the tooltip lists the connected
// devices ("Devices connected: N", waybar parity, plus their names).
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

    visible: adapter !== null
    interactive: true
    text: !adapter || !adapter.enabled ? "bt off" : (connected.length > 0 ? "bt " + connected.length : "bt")
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
