pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Elsewhen.js" as E

// World-clock state behind Panels/ElsewhenPanel: the saved city list (a state
// file the shell owns, since shell.json is generated and read-only), zone
// offsets from one `date` probe, Open-Meteo place search and temperatures.
// Nothing runs while the panel is closed: `active` (set by the panel) gates the
// probe, the temperature fetch and their refresh timers.
QtObject {
    id: root

    property bool active: false
    property bool loaded: false
    property var cfg: E.defaultState()
    // {zone: {min, abbr}} from the last offset probe.
    property var offsets: ({})
    // Celsius per city, index-aligned with cfg.cities (null = unknown).
    property var temps: []
    property double tempsAt: 0
    property var results: []
    property bool searching: false
    property string pendingQuery: ""

    readonly property double nowMs: Clock.date.getTime()
    readonly property int localOffset: -new Date(root.nowMs).getTimezoneOffset()
    readonly property int homeOffset: root.offsetOf(root.cfg.home)

    function offsetOf(zone: string): int {
        if (zone === "")
            return root.localOffset;
        const o = root.offsets[zone];
        return o ? o.min : root.localOffset;
    }

    function partsFor(zone: string): var {
        return E.zoneParts(root.nowMs, root.offsetOf(zone));
    }

    function commit(next): void {
        root.cfg = next;
        saveTimer.restart();
        root.refreshOffsets();
        root.temps = [];
        root.tempsAt = 0;
        root.refreshTemps();
    }

    function addCity(place): void {
        root.commit(E.withCity(root.cfg, place));
        root.clearSearch();
    }

    function removeCity(index: int): void {
        root.commit(E.withoutCity(root.cfg, index));
    }

    function setPeople(index: int, names: string): void {
        root.commit(E.withPeople(root.cfg, index, names));
    }

    function toggleHome(zone: string): void {
        root.commit(E.withHome(root.cfg, zone));
    }

    function toggle(key: string): void {
        root.cfg = E.withToggle(root.cfg, key);
        saveTimer.restart();
    }

    function clearSearch(): void {
        root.results = [];
        root.pendingQuery = "";
        debounce.stop();
    }

    function search(query: string): void {
        const q = query.trim();
        if (q.length < 3) {
            root.clearSearch();
            return;
        }
        root.pendingQuery = q;
        debounce.restart();
    }

    function refreshOffsets(): void {
        if (!root.active || root.offsetProbe.running)
            return;
        const zones = root.cfg.cities.map(c => c.tz).filter((z, i, a) => a.indexOf(z) === i);
        if (zones.length === 0)
            return;
        root.offsetProbe.zones = zones;
        root.offsetProbe.command = [Config.bash, "-c", "d=$1; shift; for z; do TZ=$z \"$d\" '+%z %Z'; done", "bash", Config.date].concat(zones);
        root.offsetProbe.running = true;
    }

    // Temperatures change slowly: refetch at most every 20 minutes.
    function refreshTemps(): void {
        if (!root.active || root.tempProbe.running || root.cfg.cities.length === 0)
            return;
        if (root.temps.length > 0 && Date.now() - root.tempsAt < 1200000)
            return;
        root.tempProbe.count = root.cfg.cities.length;
        root.tempProbe.command = [Config.curl, "-sf", "--max-time", "15", E.weatherUrl(root.cfg.cities)];
        root.tempProbe.running = true;
    }

    onActiveChanged: {
        if (root.active) {
            root.refreshOffsets();
            root.refreshTemps();
        } else {
            root.clearSearch();
        }
    }

    readonly property var stateFile: FileView {
        id: stateFile
        path: Quickshell.statePath("elsewhen.json")
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.cfg = E.normalizeState(text());
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    readonly property var saveTimer: Timer {
        interval: 500
        onTriggered: {
            if (root.loaded)
                stateFile.setText(JSON.stringify(root.cfg));
        }
    }

    readonly property var debounce: Timer {
        interval: 300
        onTriggered: {
            if (geocodeProbe.running)
                return;
            geocodeProbe.query = root.pendingQuery;
            root.searching = true;
            geocodeProbe.command = [Config.curl, "-sf", "--max-time", "10", E.geocodeUrl(root.pendingQuery, 5)];
            geocodeProbe.running = true;
        }
    }

    // Offsets move only at a DST boundary: re-run every five minutes while open.
    readonly property var offsetTimer: Timer {
        interval: 300000
        repeat: true
        running: root.active
        onTriggered: root.refreshOffsets()
    }

    readonly property var offsetProbe: Process {
        property var zones: []
        stdout: StdioCollector {
            onStreamFinished: root.offsets = Object.assign({}, root.offsets, E.parseOffsets(text, root.offsetProbe.zones))
        }
    }

    readonly property var tempProbe: Process {
        property int count: 0
        stdout: StdioCollector {
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                root.temps = E.parseWeather(text, root.tempProbe.count);
                root.tempsAt = Date.now();
            }
        }
    }

    readonly property var geocodeProbe: Process {
        id: geocodeProbe
        property string query: ""
        stdout: StdioCollector {
            readonly property int maxChars: 256 * 1024
            onStreamFinished: {
                if (text.length <= maxChars && geocodeProbe.query === root.pendingQuery)
                    root.results = E.parseGeocode(text, 5);
            }
        }
        onExited: code => {
            root.searching = false;
            if (code !== 0 && geocodeProbe.query === root.pendingQuery)
                root.results = [];
            if (geocodeProbe.query !== root.pendingQuery && root.pendingQuery !== "")
                debounce.restart();
        }
    }
}
