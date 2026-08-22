import Quickshell.Networking
import qs.Ui
import qs.Commons

// Connectivity readout via the native Networking binding: "wifi" / "eth" when a
// device is connected, "offline" otherwise. The native API does not expose the
// active SSID or signal strength, so waybar's richer "{essid} {signal}%" form is
// left for a later refinement (an nmcli-backed variant) — see shell/README.md.
BarItem {
  id: root

  readonly property var activeDevice: {
    const devs = Networking.devices ? Networking.devices.values : [];
    for (let i = 0; i < devs.length; i++)
      if (devs[i].connected)
        return devs[i];
    return null;
  }

  text: {
    if (!activeDevice)
      return "offline";
    return activeDevice.type === DeviceType.Wired ? "eth" : "wifi";
  }
  textColor: activeDevice ? Color.text : Color.textFaint
}
