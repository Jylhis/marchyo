pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/WifiQr.js" as Qr

QtObject {
    id: root

    property string ssid: ""
    property string password: ""
    property bool secured: false
    property bool loading: false
    property string error: ""
    property var matrix: ({
            size: 0,
            cells: []
        })
    property int generation: 0
    property bool pending: false
    property string uuid: ""
    property string detailsText: ""
    property string qrOutput: ""

    function cancel(): void {
        generation++;
        pending = false;
        active.running = false;
        details.running = false;
        render.running = false;
        ssid = "";
        password = "";
        uuid = "";
        detailsText = "";
        qrOutput = "";
        secured = false;
        matrix = {
            size: 0,
            cells: []
        };
        error = "";
        loading = false;
    }

    function generate(): void {
        cancel();
        loading = true;
        pending = true;
        startPending.restart();
    }

    function start(process): void {
        process.token = generation;
        process.busy = true;
        process.running = true;
    }

    function stopped(process): void {
        if (process.running || !process.busy || Number(process.processId) > 0)
            return;
        process.busy = false;
        if (process.token === generation)
            fail("wifiqr.failed");
        startPending.restart();
    }

    function fail(key: string): void {
        loading = false;
        password = "";
        matrix = {
            size: 0,
            cells: []
        };
        error = I18n.t(key);
    }

    property Timer startPending: Timer {
        interval: 0
        onTriggered: {
            if (!root.pending || active.busy || details.busy || render.busy)
                return;
            root.pending = false;
            root.start(active);
        }
    }

    property Process active: Process {
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.stopped, active);
        }
        property int token: -1
        property bool busy: false
        command: [Config.nmcli, "-t", "-f", "UUID,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (active.token !== root.generation)
                    return;
                const line = text.split("\n").find(l => /:(802-11-wireless|wifi)$/.test(l));
                root.uuid = line ? line.split(":")[0] : "";
            }
        }
        onExited: code => {
            busy = false;
            startPending.restart();
            if (token !== root.generation)
                return;
            if (code !== 0 || !root.uuid) {
                root.fail(code !== 0 ? "wifiqr.failed" : "wifiqr.noNetwork");
                return;
            }
            root.start(details);
        }
    }

    property Process details: Process {
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.stopped, details);
        }
        property int token: -1
        property bool busy: false
        command: [Config.nmcli, "--escape", "no", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk", "connection", "show", "uuid", root.uuid]
        stdout: SplitParser {
            onRead: line => {
                if (details.token === root.generation)
                    root.detailsText += line + "\n";
            }
        }
        onExited: code => {
            busy = false;
            startPending.restart();
            if (token !== root.generation)
                return;
            const fields = root.detailsText.replace(/\r/g, "").split("\n");
            root.ssid = fields[0] || "";
            const security = fields[1] === "--" ? "" : fields[1] || "";
            const secret = fields[2] === "--" ? "" : fields[2] || "";
            root.detailsText = "";
            if (code !== 0 || !Qr.payload(root.ssid, security, secret)) {
                root.fail("wifiqr.failed");
                return;
            }
            root.secured = security !== "";
            root.password = secret;
            render.stdinEnabled = true;
            root.start(render);
        }
    }

    property Process render: Process {
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.stopped, render);
        }
        property int token: -1
        property bool busy: false
        command: [Config.qrencode, "-t", "ASCII", "-m", "4", "-o", "-"]
        onStarted: {
            if (token !== root.generation)
                return;
            write(Qr.payload(root.ssid, root.secured ? "wpa-psk" : "", root.password));
            stdinEnabled = false;
        }
        stdout: SplitParser {
            onRead: line => {
                if (render.token === root.generation)
                    root.qrOutput += line + "\n";
            }
        }
        onExited: code => {
            busy = false;
            startPending.restart();
            if (token !== root.generation)
                return;
            root.matrix = Qr.parseAscii(root.qrOutput);
            root.qrOutput = "";
            root.loading = false;
            if (code !== 0 || root.matrix.size === 0)
                root.fail("wifiqr.failed");
        }
    }
}
