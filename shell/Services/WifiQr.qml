pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// On-demand Wi-Fi QR for the current network. generate() runs a short chain:
// find the active SSID, read its PSK (nmcli -s, authorized for the active
// session by NetworkManager's default polkit), then render a scannable QR as a
// UTF8 half-block text grid with qrencode — no temp files, no image plumbing.
// Falls back to an open-network (no-password) QR when the PSK is unavailable.
//
// Ported from omarchy's wifiqr panel. Not a seat-global status like the other
// singletons; it holds the last generated QR so the panel can bind to it, and
// only runs when the panel asks it to.
QtObject {
    id: root

    property string ssid: ""
    property string qrText: ""
    property string error: ""

    property string _psk: ""

    // WIFI: URI escaping — backslash-escape \ ; , : and " (MECARD grammar).
    function esc(s): string {
        return String(s || "").replace(/([\\;,:"])/g, "\\$1");
    }

    function generate(): void {
        root.qrText = "";
        root.error = "";
        root.ssid = "";
        root._psk = "";
        ssidProc.running = true;
    }

    function buildAndRender(): void {
        if (root.ssid === "") {
            root.error = "No active Wi-Fi network";
            return;
        }
        const body = root._psk !== "" ? ("WIFI:T:WPA;S:" + root.esc(root.ssid) + ";P:" + root.esc(root._psk) + ";;") : ("WIFI:T:nopass;S:" + root.esc(root.ssid) + ";;");
        qrProc.command = [Config.qrencode, "-t", "UTF8", "-o", "-", body];
        qrProc.running = true;
    }

    // 1) Active SSID from `nmcli -t -f active,ssid dev wifi` (line "yes:<ssid>").
    readonly property var ssidProc: Process {
        id: ssidProc
        command: [Config.nmcli, "-t", "-f", "active,ssid", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text).split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("yes:") === 0) {
                        root.ssid = lines[i].slice(4);
                        break;
                    }
                }
            }
        }
        onExited: {
            if (root.ssid === "") {
                root.error = "No active Wi-Fi network";
                return;
            }
            pskProc.command = [Config.nmcli, "-s", "-g", "802-11-wireless-security.psk", "connection", "show", root.ssid];
            pskProc.running = true;
        }
    }

    // 2) PSK for that connection (may be empty: open network, or not authorized).
    readonly property var pskProc: Process {
        id: pskProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._psk = String(text).trim()
        }
        onExited: root.buildAndRender()
    }

    // 3) Render the QR to a UTF8 text grid.
    readonly property var qrProc: Process {
        id: qrProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.qrText = String(text)
        }
        onExited: code => {
            if (code !== 0)
                root.error = "Could not render QR";
        }
    }
}
