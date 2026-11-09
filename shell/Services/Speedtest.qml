pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Speedtest.js" as ST
import "../Commons/Paths.js" as Paths

// On-demand network and disk speed tests for the speed test panel. Only runs
// when the panel asks, one step at a time: ping, download and upload against
// Cloudflare's speed endpoints with curl, then a 512 MiB write and read with dd
// in the user cache directory (removed afterwards). Results stay until the next
// run; an unknown value reads -1.
QtObject {
    id: root

    // "" while idle, else the step that runs: ping, down, up, write or read.
    property string phase: ""
    readonly property bool running: root.phase !== ""
    property real pingMs: -1
    property real downMbps: -1
    property real upMbps: -1
    property real writeMBps: -1
    property real readMBps: -1
    property string error: ""
    // "network" or "disk": which test the running steps belong to.
    property string kind: ""

    readonly property string host: "https://speed.cloudflare.com"

    function diskFile(): string {
        return Paths.xdgDir(Quickshell.env("XDG_CACHE_HOME"), Quickshell.env("HOME"), "/.cache") + "/marchyo/speedtest.bin";
    }

    function startNetwork(): void {
        if (root.running)
            return;
        root.kind = "network";
        root.error = "";
        root.pingMs = -1;
        root.downMbps = -1;
        root.upMbps = -1;
        root.step("ping");
    }

    function startDisk(): void {
        if (root.running)
            return;
        root.kind = "disk";
        root.error = "";
        root.writeMBps = -1;
        root.readMBps = -1;
        root.step("write");
    }

    function stop(): void {
        proc.running = false;
        root.phase = "";
    }

    function commandFor(phase: string): var {
        switch (phase) {
        case "ping":
            return [Config.curl, "-s", "-o", "/dev/null", "-m", "8", "-w", "%{time_starttransfer}", root.host + "/__down?bytes=0"];
        case "down":
            return [Config.curl, "-s", "-o", "/dev/null", "-m", "15", "-w", "%{speed_download}", root.host + "/__down?bytes=100000000"];
        case "up":
            return [Config.bash, "-c", "head -c 25000000 /dev/zero | \"$1\" -s -m 20 -o /dev/null -w '%{speed_upload}' --data-binary @- \"$2\"", "x", Config.curl, root.host + "/__up"];
        case "write":
            return [Config.bash, "-c", "mkdir -p \"$(dirname \"$1\")\" && dd if=/dev/zero of=\"$1\" bs=1M count=512 conv=fdatasync 2>&1 | tail -n 1", "x", root.diskFile()];
        default:
            return [Config.bash, "-c", "{ dd if=\"$1\" of=/dev/null bs=1M iflag=direct 2>&1 || dd if=\"$1\" of=/dev/null bs=1M 2>&1; } | tail -n 1; rm -f \"$1\"", "x", root.diskFile()];
        }
    }

    function step(phase: string): void {
        root.phase = phase;
        proc.command = root.commandFor(phase);
        proc.running = true;
    }

    // Record one step's output and start the next, or finish the run. A curl
    // timeout (exit 28) still prints the average speed, so output decides.
    function finish(text: string): void {
        const phase = root.phase;
        if (phase === "ping") {
            root.pingMs = ST.pingMsFromCurl(text);
            if (root.pingMs < 0) {
                root.fail("speedtest.offline");
                return;
            }
            root.step("down");
        } else if (phase === "down") {
            root.downMbps = ST.mbpsFromCurl(text);
            root.step("up");
        } else if (phase === "up") {
            root.upMbps = ST.mbpsFromCurl(text);
            root.phase = "";
        } else if (phase === "write") {
            root.writeMBps = ST.mbPerSecFromDd(text);
            if (root.writeMBps < 0) {
                root.fail("speedtest.diskFailed");
                return;
            }
            root.step("read");
        } else if (phase === "read") {
            root.readMBps = ST.mbPerSecFromDd(text);
            root.phase = "";
        }
    }

    function fail(key: string): void {
        root.error = key;
        root.phase = "";
    }

    readonly property var runner: Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.phase !== "")
                    root.finish(String(text));
            }
        }
    }
}
