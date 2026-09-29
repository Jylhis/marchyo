import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Tailscale status indicator: a pure view over Services/Tailscale. Self-hides
// on hosts without tailscale (marchyo.services.tailscale.enable off, so the CLI
// is not baked, the probe fails, and installed stays false). Registered but not
// placed in the default layout: add marchyo.tailscale to a section to show it.
BarItem {
    id: root

    interactive: true
    visible: Tailscale.installed
    onClicked: PanelManager.toggle("tailscale", root)
    text: Tailscale.exitNodeActive ? "󰖂" : (Tailscale.running ? "󰖂" : "󰖃")
    textColor: Tailscale.running ? (Tailscale.exitNodeActive ? Color.accent : Color.statusOk) : Color.textMuted
    tooltipText: {
        if (!Tailscale.running)
            return "Tailscale disconnected";
        const who = Tailscale.selfName + (Tailscale.selfIp !== "" ? " (" + Tailscale.selfIp + ")" : "");
        if (Tailscale.exitNodeActive)
            return "Tailscale: " + who + "\nExit node: " + Tailscale.exitNodeName;
        return "Tailscale: " + who;
    }
}
