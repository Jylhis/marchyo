pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared Tailscale state: ONE `tailscale status --json` poll for the whole seat.
//
// A trimmed port of omarchy's tailscale panel Service — an indicator, not the
// full exit-node/Taildrop/accounts panel. The tailscale CLI is only baked into
// Config when marchyo.services.tailscale.enable is set (see package.nix); on
// other hosts the bare name is baked, the probe fails, and `installed` stays
// false so the widget self-hides. Singleton for the usual reason: the widget is
// a pure per-monitor view and this state is seat-global.
QtObject {
    id: root

    property bool installed: false
    property bool running: false
    property bool exitNodeActive: false
    property string exitNodeName: ""
    property string selfName: ""
    property string selfIp: ""

    function first100(ips): string {
        if (!ips)
            return "";
        for (var i = 0; i < ips.length; i++) {
            const ip = String(ips[i] || "");
            if (ip.indexOf("100.") === 0)
                return ip;
        }
        return "";
    }

    function apply(text: string): void {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return; // keep last-good on a partial/garbled read
        }
        if (!data || typeof data !== "object")
            return;
        root.running = String(data.BackendState || "") === "Running";
        const self = data.Self || {};
        const dns = String(self.DNSName || "");
        root.selfName = (self.HostName && String(self.HostName)) || (dns.charAt(dns.length - 1) === "." ? dns.slice(0, -1) : dns);
        root.selfIp = root.first100(self.TailscaleIPs || data.TailscaleIPs || []);
        // An active exit node shows up as a peer with ExitNode === true.
        let en = "";
        const peers = data.Peer || {};
        for (var id in peers) {
            const p = peers[id] || {};
            if (p.ExitNode === true) {
                const pdns = String(p.DNSName || "");
                en = (p.HostName && String(p.HostName)) || (pdns.charAt(pdns.length - 1) === "." ? pdns.slice(0, -1) : pdns);
                break;
            }
        }
        root.exitNodeName = en;
        root.exitNodeActive = en !== "";
    }

    readonly property var probe: Process {
        id: probe
        command: [Config.tailscale, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: code => {
            root.installed = (code === 0 || code === 1); // 1 = installed but logged out/down
            if (code !== 0 && code !== 1) {
                root.installed = false;
                root.running = false;
                root.exitNodeActive = false;
            }
        }
    }

    readonly property var poll: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
