pragma Singleton
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../Commons/Bluetooth.js" as BT

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool scanning: root.available && root.adapter.discovering
    property var pendingActions: ({})
    property var audioRoutes: ({})
    property int openPanels: 0
    property var scanAdapter: null
    property bool ownsScan: false

    readonly property var connected: rows.filter(r => r.connected).map(r => r.name)
    readonly property var sections: BT.sections(root.rows, root.scanning)
    readonly property var rows: {
        const out = [];
        const devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (const d of devices) {
            if (d.adapter !== root.adapter)
                continue;
            const pending = root.pendingActions[d.address];
            let status = pending ? pending.action : "";
            if (!status && d.pairing)
                status = "pair";
            if (!status && d.state === BluetoothDeviceState.Connecting)
                status = "connect";
            if (!status && d.state === BluetoothDeviceState.Disconnecting)
                status = "disconnect";
            out.push({
                         name: d.name || d.deviceName || d.address,
                         address: d.address,
                         connected: d.connected,
                         paired: d.paired || d.bonded,
                         busy: status !== "",
                         status: status,
                         battery: BT.batteryText(d.batteryAvailable, d.battery)
                     });
        }
        return BT.sortRows(out);
    }

    function deviceFor(address) {
        const devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        return devices.find(d => d.adapter === root.adapter && d.address === address) || null;
    }

    function setScanning(on: bool): void {
        if (!root.enabled)
            return;
        if (on && !root.scanning && root.openPanels > 0) {
            root.scanAdapter = root.adapter;
            root.ownsScan = true;
        }
        root.adapter.discovering = on;
        if (!on)
            root.ownsScan = false;
    }

    function acquireScan(): void {
        root.openPanels++;
        root.setScanning(true);
    }

    function releaseScan(): void {
        root.openPanels = Math.max(0, root.openPanels - 1);
        if (root.openPanels !== 0 || !root.ownsScan)
            return;
        if (root.scanAdapter && root.scanAdapter.enabled)
            root.scanAdapter.discovering = false;
        root.ownsScan = false;
        root.scanAdapter = null;
    }

    onEnabledChanged: {
        if (root.enabled && root.openPanels > 0)
            root.setScanning(true);
        else if (!root.enabled) {
            root.ownsScan = false;
            root.scanAdapter = null;
            root.pendingActions = ({});
            root.audioRoutes = ({});
        }
    }

    function beginAction(row, action): void {
        const device = root.deviceFor(row.address);
        if (!device || row.busy || root.pendingActions[row.address] || action === "none")
            return;
        const next = Object.assign({}, root.pendingActions);
        next[row.address] = {
            action: action,
            expires: Date.now() + 15000
        };
        root.pendingActions = next;
        if (action === "forget")
            device.forget();
        else if (action === "disconnect")
            device.disconnect();
        else if (action === "connect")
            device.connect();
        else if (action === "pair")
            device.pair();
    }

    function activate(row): void {
        root.beginAction(row, BT.actionFor(row));
    }

    function forget(row): void {
        if (row.paired)
            root.beginAction(row, "forget");
    }

    function settleActions(): void {
        const next = Object.assign({}, root.pendingActions);
        for (const address of Object.keys(next)) {
            const pending = root.advanceAction(address, next[address]);
            if (pending)
                next[address] = pending;
            else
                delete next[address];
        }
        if (JSON.stringify(next) !== JSON.stringify(root.pendingActions))
            root.pendingActions = next;
    }

    function advanceAction(address, pending) {
        const device = root.deviceFor(address);
        if (!device || Date.now() > pending.expires)
            return null;
        const connecting = pending.action === "connect" || pending.action === "pair";
        if (connecting && device.connected) {
            const routes = Object.assign({}, root.audioRoutes);
            routes[address] = {
                name: device.name,
                address: address,
                tries: 0
            };
            root.audioRoutes = routes;
            return null;
        }
        if (pending.action === "pair" && device.paired) {
            device.connect();
            return {
                action: "connect",
                expires: Date.now() + 15000
            };
        }
        if (pending.action === "disconnect" && !device.connected)
            return null;
        if (pending.action === "forget" && !device.paired && !device.bonded)
            return null;
        return pending;
    }

    function routeAudio(): void {
        const routes = Object.assign({}, root.audioRoutes);
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (const address of Object.keys(routes)) {
            const route = routes[address];
            const device = root.deviceFor(address);
            const sink = nodes.find(n => BT.sinkMatchesDevice(n, route));
            if (device && device.connected && sink)
                Pipewire.preferredDefaultAudioSink = sink;
            if (!device || !device.connected || sink || route.tries >= 7)
                delete routes[address];
            else
                routes[address] = {
                    name: route.name,
                    address: address,
                    tries: route.tries + 1
                };
        }
        root.audioRoutes = routes;
    }

    readonly property Timer actionTimer: Timer {
        interval: 250
        repeat: true
        running: Object.keys(root.pendingActions).length > 0
        onTriggered: root.settleActions()
    }

    readonly property Timer routeTimer: Timer {
        interval: 500
        repeat: true
        running: Object.keys(root.audioRoutes).length > 0
        onTriggered: root.routeAudio()
    }

    readonly property PwObjectTracker routeTracker: PwObjectTracker {
        objects: {
            if (Object.keys(root.audioRoutes).length === 0 || !Pipewire.nodes)
                return [];
            return Pipewire.nodes.values.filter(n => n.isSink && !n.isStream);
        }
    }

    function setEnabled(on: bool): void {
        if (root.available)
            root.adapter.enabled = on;
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }
}
