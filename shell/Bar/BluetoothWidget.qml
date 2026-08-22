import Quickshell.Bluetooth
import qs.Ui
import qs.Commons

// Bluetooth status via the native BlueZ binding. "bt off" when the adapter is
// disabled, "bt N" with a connected count, else "bt". Matches waybar's format.
BarItem {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property int connected: {
    let n = 0;
    const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
    for (let i = 0; i < devs.length; i++)
      if (devs[i].connected)
        n++;
    return n;
  }

  visible: adapter !== null
  text: !adapter || !adapter.enabled ? "bt off" : (connected > 0 ? "bt " + connected : "bt")
  textColor: (adapter && adapter.enabled) ? Color.text : Color.textFaint
}
