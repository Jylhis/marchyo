import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Tailscale status indicator: a pure view over Services/Tailscale. Self-hides
// on hosts without tailscale (marchyo.services.tailscale.enable off → the CLI
// is not baked → the probe fails → installed stays false). Informational; the
// full exit-node / Taildrop panel is a separate, larger port. Registered but
// not placed in the default layout — add marchyo.tailscale to a section to
// show it.
BarItem {
    id: root

    visible: Tailscale.installed
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
