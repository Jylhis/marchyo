pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "../Commons/Displays.js" as D
import "../Commons/Paths.js" as Paths

// Display state and actions for Panels/DisplayPanel: the connected displays
// from `hyprctl monitors all -j`, their brightness, and the changes the panel
// makes. A change is applied to Hyprland in one `hyprctl eval` and, when
// Config.monitorPersist is set, remembered in
// $XDG_STATE_HOME/marchyo/monitors/settings, which
// modules/home/hyprland-monitor-settings.lua applies after a reload. One
// probe for the whole seat, so a singleton.
QtObject {
    id: root

    property var displays: []
    property string selected: ""
    // Connector -> brightness percent, for the displays that report one.
    property var brightness: ({})
    // Connector -> i2c bus, from `ddcutil detect`.
    property var ddcBuses: ({})
    property bool ddcProbed: false

    readonly property var current: root.displays.find(d => d.name === root.selected) || null
    readonly property var layout: D.layoutDisplays(root.displays)

    readonly property string stateDir: Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/monitors"

    function open(): void {
        root.refresh();
        if (!root.ddcProbed) {
            root.ddcProbed = true;
            ddcProbe.running = true;
        }
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    function select(name: string): void {
        root.selected = name;
        root.readBrightness(name);
    }

    function byName(name: string): var {
        return root.displays.find(d => d.name === name) || null;
    }

    // ---- Changes ----

    function applyPlan(plan): void {
        const expr = D.buildEval(plan.entries);
        if (expr === "")
            return;
        root.run(expr);
        root.save(plan.saves);
    }

    function setMode(name: string, size: string, rate: string): void {
        const d = root.byName(name);
        const mode = d ? D.modeFor(d.modes, size, rate) : "";
        if (mode !== "")
            root.applyPlan(D.planChange(root.displays, name, {
                mode: mode
            }));
    }

    function setScale(name: string, scale: real): void {
        root.applyPlan(D.planChange(root.displays, name, {
            scale: scale
        }));
    }

    function rotate(name: string): void {
        const d = root.byName(name);
        if (d)
            root.applyPlan(D.planChange(root.displays, name, {
                transform: D.nextRotation(d.transform)
            }));
    }

    function setRotation(name: string, degrees: int): void {
        root.applyPlan(D.planChange(root.displays, name, {
            transform: D.transformFor(degrees)
        }));
    }

    function placeBeside(name: string, target: string, right: bool): void {
        const rects = D.placeBeside(root.layout.map(D.logicalRect), name, target, right);
        if (!rects)
            return;
        const saves = {};
        rects.forEach(r => saves[r.name] = {
                position: Math.round(r.x) + "x" + Math.round(r.y)
            });
        root.applyPlan({
            entries: D.layoutEntries(rects),
            saves: saves
        });
    }

    function setEnabled(name: string, on: bool): void {
        const d = root.byName(name);
        if (!d || (!on && D.enabledCount(root.displays) < 2))
            return;
        const entry = on ? {
            output: name,
            mode: "preferred",
            position: "auto",
            scale: d.scale > 0 ? d.scale : undefined
        } : {
            output: name,
            disabled: true
        };
        root.applyPlan({
            entries: [entry],
            saves: {
                [name]: {
                    enabled: on
                }
            }
        });
    }

    // Move one display in the layout map: (x, y) is where its corner was
    // dropped, in layout pixels.
    function drop(name: string, x: real, y: real): void {
        const rects = root.layout.map(D.logicalRect);
        const placed = D.dropDisplay(rects, name, x, y, 80);
        if (!placed || D.sameLayout(placed, rects))
            return;
        const saves = {};
        placed.forEach(r => saves[r.name] = {
                position: Math.round(r.x) + "x" + Math.round(r.y)
            });
        root.applyPlan({
            entries: D.layoutEntries(placed),
            saves: saves
        });
    }

    // Extend (each display its own area) or Mirror (the external displays show
    // the built-in panel).
    property var mirrorWanted: null
    property var mirrorPrevious: ({})
    property string mirrorError: ""
    property bool verifyMirror: false
    property Timer mirrorRecheck: Timer {
        interval: 1500
        onTriggered: {
            root.verifyMirror = true;
            root.refresh();
        }
    }

    function checkMirror(): void {
        if (!root.verifyMirror || root.mirrorWanted === null)
            return;
        if (!D.mirrorMatches(root.displays, root.mirrorWanted)) {
            root.save(root.mirrorPrevious);
            root.mirrorError = I18n.t("display.mirrorFailed");
        }
        root.mirrorWanted = null;
        root.verifyMirror = false;
    }

    function setMirror(on: bool): void {
        if (root.mirrorWanted !== null)
            return;
        const internal = root.displays.find(d => d.internal && d.enabled);
        const externals = root.displays.filter(d => !d.internal && d.enabled);
        if (!internal || externals.length === 0)
            return;
        root.mirrorWanted = on;
        root.mirrorError = "";
        const previous = {};
        externals.forEach(d => previous[d.name] = {
                mirror: d.mirrorOf ? "internal" : ""
            });
        root.mirrorPrevious = previous;
        const saves = {};
        externals.forEach(d => saves[d.name] = {
                mirror: on ? "internal" : ""
            });
        root.save(saves);
        if (on) {
            root.run(D.buildEval(externals.map(d => ({
                        output: d.name,
                        mode: "preferred",
                        position: "auto",
                        scale: 1,
                        mirror: internal.name
                    }))));
        } else {
            reloadProc.running = true;
        }
    }

    function setBrightness(name: string, percent: int): void {
        const value = D.clampBrightness(percent);
        const next = Object.assign({}, root.brightness);
        next[name] = value;
        root.brightness = next;
        brightnessWrite.target = name;
        brightnessWrite.value = value;
        brightnessWrite.restart();
    }

    // ---- Plumbing ----

    property var evalQueue: []

    function run(expr: string): void {
        if (expr === "")
            return;
        if (evalProc.running) {
            root.evalQueue = root.evalQueue.concat([expr]);
            return;
        }
        evalProc.command = [Config.hyprctl, "eval", expr];
        evalProc.running = true;
    }

    property Process evalProc: Process {
        onExited: {
            if (root.evalQueue.length > 0) {
                const next = root.evalQueue[0];
                root.evalQueue = root.evalQueue.slice(1);
                root.run(next);
                return;
            }
            root.refresh();
            if (root.mirrorWanted !== null)
                root.mirrorRecheck.restart();
        }
    }

    property Process reloadProc: Process {
        command: [Config.hyprctl, "reload"]
        onExited: {
            root.refresh();
            if (root.mirrorWanted !== null)
                root.mirrorRecheck.restart();
        }
    }

    property Process listProc: Process {
        onExited: root.checkMirror()
        command: [Config.hyprctl, "monitors", "all", "-j"]
        stdout: StdioCollector {
            // A tripwire against an answer no healthy hyprctl could produce.
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                root.displays = D.parseDisplays(text);
                const known = root.byName(root.selected);
                if (!known) {
                    const focused = root.displays.find(d => d.focused) || root.displays[0];
                    root.selected = focused ? focused.name : "";
                }
                root.readBrightness(root.selected);
            }
        }
    }

    // A monitor plugged in or out while the panel is open.
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremoved")
                root.refresh();
        }
    }

    // ---- Brightness ----

    property var readQueue: []

    function readBrightness(name: string): void {
        const d = root.byName(name);
        if (!d || !d.enabled)
            return;
        const bus = root.ddcBuses[name];
        if (d.internal)
            root.queueRead({
                name: name,
                argv: [Config.brightnessctl, "-m"]
            });
        else if (bus !== undefined)
            root.queueRead({
                name: name,
                argv: [Config.ddcutil, "--bus", String(bus), "getvcp", "10", "--terse"]
            });
    }

    function queueRead(job): void {
        if (root.readQueue.some(j => j.name === job.name))
            return;
        root.readQueue = root.readQueue.concat([job]);
        root.nextRead();
    }

    function nextRead(): void {
        if (readProc.running || root.readQueue.length === 0)
            return;
        const job = root.readQueue[0];
        root.readQueue = root.readQueue.slice(1);
        readProc.job = job;
        readProc.command = job.argv;
        readProc.running = true;
    }

    property Process readProc: Process {
        property var job: null
        stdout: StdioCollector {
            onStreamFinished: {
                const job = readProc.job;
                if (!job)
                    return;
                const pct = job.argv[0] === Config.brightnessctl ? D.backlightPercent(text) : D.parseVcp(text);
                if (pct > 0) {
                    const next = Object.assign({}, root.brightness);
                    next[job.name] = pct;
                    root.brightness = next;
                }
            }
        }
        onExited: root.nextRead()
    }

    property Process ddcProbe: Process {
        command: [Config.ddcutil, "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ddcBuses = D.parseDdcDetect(text);
                if (root.selected !== "")
                    root.readBrightness(root.selected);
            }
        }
    }

    // One write after the slider settles, not one per drag step.
    property Timer brightnessWrite: Timer {
        property string target: ""
        property int value: 0
        interval: 150
        onTriggered: {
            const d = root.byName(target);
            if (!d)
                return;
            const bus = root.ddcBuses[target];
            if (d.internal)
                writeProc.command = [Config.brightnessctl, "-e4", "-n2", "set", value + "%"];
            else if (bus !== undefined)
                writeProc.command = [Config.ddcutil, "--bus", String(bus), "setvcp", "10", String(value)];
            else
                return;
            writeProc.running = true;
        }
    }

    property Process writeProc: Process {}

    // ---- Saved settings ----

    property var pendingSaves: []

    function save(saves): void {
        if (!Config.monitorPersist)
            return;
        root.pendingSaves = root.pendingSaves.concat([saves]);
        if (!mkdirProc.running)
            mkdirProc.running = true;
    }

    property Process mkdirProc: Process {
        command: [Config.mkdir, "-p", root.stateDir]
        onExited: {
            settingsFile.reload();
            let settings = D.parseSettings(settingsFile.text());
            root.pendingSaves.forEach(saves => settings = D.applySaves(settings, root.displays, saves));
            root.pendingSaves = [];
            settingsFile.setText(D.serializeSettings(settings));
        }
    }

    property FileView settingsFile: FileView {
        path: root.stateDir + "/settings"
        blockLoading: true
        printErrors: false
    }
}
