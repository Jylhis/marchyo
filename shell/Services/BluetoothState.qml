pragma Singleton
import QtQuick
import Quickshell.Bluetooth

// Shared Bluetooth state over the native BlueZ binding: the default adapter,
// its power state, and the connected device names. Read by the bar's
// BluetoothWidget and the Control Center tile; setEnabled() powers the adapter
// through BlueZ (no subprocess).
QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter
    readonly property bool enabled: root.available && root.adapter.enabled

    // Display names of the connected devices (name, else address).
    readonly property var connected: {
        const out = [];
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < devs.length; i++)
            if (devs[i].connected)
                out.push(devs[i].name || devs[i].address);
        return out;
    }

    function setEnabled(on: bool): void {
        if (root.available)
            root.adapter.enabled = on;
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }
}
