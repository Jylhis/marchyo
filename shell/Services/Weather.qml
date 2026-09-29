pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared weather state: ONE wttr.in fetch for the whole seat.
//
// Trimmed port of omarchy's weather plugin — the bar widget's current
// conditions, not the location-picker/forecast panel (that lands with the Ui
// primitive harvest). Location is IP-geolocated by wttr.in. This singleton is
// only instantiated when a weather widget is placed in the bar layout, so a
// host that never adds the widget makes no outbound request. Singleton for the
// usual reason: the widget is a pure per-monitor view and this is seat-global.
QtObject {
    id: root

    property bool available: false
    property string tempC: ""
    property string description: ""
    property string icon: ""

    // WWO weather codes (wttr.in) → nerd-font glyphs, a compact subset of
    // omarchy's iconForCode map: clear, cloud, fog, rain, snow, thunder.
    function iconForCode(code): string {
        const c = parseInt(String(code || "0"), 10);
        if (c === 113)
            return "";
        if (c === 116 || c === 119 || c === 122)
            return "";
        if (c === 143 || c === 248 || c === 260)
            return "";
        if (c === 179 || c === 227 || c === 230 || c === 323 || c === 326 || c === 338 || c === 371)
            return "";
        if (c === 200 || c === 386 || c === 389 || c === 392 || c === 395)
            return "";
        if (c >= 176 && c <= 377)
            return "";
        return "";
    }

    function apply(text: string): void {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return; // keep last-good on a partial/garbled read
        }
        const cur = data && data.current_condition && data.current_condition[0];
        if (!cur) {
            root.available = false;
            return;
        }
        root.tempC = String(cur.temp_C || "");
        root.description = cur.weatherDesc && cur.weatherDesc[0] ? String(cur.weatherDesc[0].value || "") : "";
        root.icon = root.iconForCode(cur.weatherCode);
        root.available = root.tempC !== "";
    }

    readonly property var probe: Process {
        id: probe
        // -s silent, -f fail on HTTP errors, generous connect/total timeouts so
        // a flaky network can never wedge the poll; j1 is wttr.in's JSON view.
        command: [Config.curl, "-sf", "--max-time", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            // Tripwire against a pathological response (wttr j1 is ~30KB).
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length <= maxChars)
                    root.apply(text);
            }
        }
        onExited: code => {
            if (code !== 0)
                root.available = false;
        }
    }

    // Weather changes slowly and wttr.in asks callers not to hammer it: refresh
    // every 30 minutes (plus once at startup).
    readonly property var poll: Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
