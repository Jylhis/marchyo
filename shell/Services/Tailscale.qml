pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared Tailscale state: ONE seat-wide `tailscale status --json` poll. The CLI
// is only baked into Config when marchyo.services.tailscale.enable is set; on
// other hosts the bare name is baked, the probe fails, and `installed` stays
// false so the widget self-hides. A singleton; this state is seat-global.
QtObject {
    id: root

    property bool installed: false
    property bool running: false
    property bool exitNodeActive: false
    property string exitNodeName: ""
    property string selfName: ""
    property string selfIp: ""
    // Online tailnet peers for the detail panel: [{ name, ip, os, online }].
    property var peers: []

    // Up/down is offered only when the CLI is baked as a store path
    // (marchyo.services.tailscale.enable) and the status probe succeeds. The
    // daemon accepts it only from root or the tailnet operator
    // (`tailscale set --operator=$USER`); any refusal lands in lastError.
    readonly property bool controllable: root.installed && Config.tailscale.indexOf("/") === 0
    property bool busy: false
    property int lastExit: 0
    property string actionStderr: ""
    readonly property string lastError: {
        if (root.lastExit === 0)
            return "";
        const line = root.actionStderr.split("\n").map(l => l.trim()).filter(l => l.length > 0)[0];
        return line || ("tailscale exited " + root.lastExit);
    }
    // Full refusal text for the detail panel (includes the CLI's operator hint).
    readonly property string lastErrorDetail: root.lastExit === 0 ? "" : (root.actionStderr.trim() || root.lastError)

    function setUp(on: bool): void {
        if (!root.controllable || root.busy)
            return;
        root.busy = true;
        root.lastExit = 0;
        root.actionStderr = "";
        // --timeout bounds `up` on a logged-out node, which would otherwise wait
        // for an interactive login indefinitely.
        action.command = on ? [Config.tailscale, "up", "--timeout=20s"] : [Config.tailscale, "down"];
        action.running = true;
    }

    readonly property var action: Process {
        id: action
        stderr: StdioCollector {
            readonly property int maxChars: 4096
            onStreamFinished: root.actionStderr = text.length <= maxChars ? text : text.slice(0, maxChars)
        }
        onExited: code => {
            root.busy = false;
            root.lastExit = code;
            probe.running = true;
        }
    }

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
        const rawPeers = data.Peer || {};
        const list = [];
        for (var id in rawPeers) {
            const p = rawPeers[id] || {};
            const pdns = String(p.DNSName || "");
            const nm = (p.HostName && String(p.HostName)) || (pdns.charAt(pdns.length - 1) === "." ? pdns.slice(0, -1) : pdns);
            if (p.ExitNode === true && en === "")
                en = nm;
            if (p.Online === true) {
                list.push({
                    name: nm,
                    ip: root.first100(p.TailscaleIPs || []),
                    os: String(p.OS || ""),
                    online: true
                });
            }
        }
        list.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        root.peers = list;
        root.exitNodeName = en;
        root.exitNodeActive = en !== "";
    }

    readonly property var probe: Process {
        id: probe
        command: [Config.tailscale, "status", "--json"]
        stdout: StdioCollector {
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length <= maxChars)
                    root.apply(text);
            }
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
