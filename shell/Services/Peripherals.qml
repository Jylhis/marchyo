pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import "../Commons/Peripherals.js" as Peripherals

// Battery status for wireless peripherals (mice / keyboards / headsets),
// aggregated in one place so the bar widget is a pure view. Native
// UPower.devices is event-driven (no polling) and covers most HID++ peripherals
// the kernel binds. The solaar fallback covers the Logi Bolt receiver
// (046d:c548) the kernel will not bind — it only runs while UPower reports no
// peripheral and only when the host baked the fallback in (marchyo.hardware
// .logitech.enable, via Style.peripheralsFallback). Like Power/Audio this is a
// singleton: the widget is instantiated once per monitor, this work is not.
QtObject {
    id: root

    readonly property int lowThreshold: 20

    function isPeripheral(t) {
        return t === UPowerDeviceType.Mouse || t === UPowerDeviceType.Keyboard || t === UPowerDeviceType.Headset || t === UPowerDeviceType.Headphones || t === UPowerDeviceType.Speakers || t === UPowerDeviceType.GamingInput || t === UPowerDeviceType.Touchpad || t === UPowerDeviceType.Tablet || t === UPowerDeviceType.Pen;
    }

    function glyphFor(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:
            return "󰍽";
        case UPowerDeviceType.Keyboard:
            return "󰌌";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "󰋋";
        case UPowerDeviceType.Speakers:
            return "󰓃";
        case UPowerDeviceType.GamingInput:
            return "󰊴";
        default:
            return "󰥉";
        }
    }

    // UPower-reported peripherals: [{name, pct, glyph, low}]. `powerSupply` is
    // the system battery/line power, excluded; `percentage` is a 0.0–1.0 fraction.
    readonly property var upowerDevices: {
        const list = UPower.devices ? UPower.devices.values : [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            if (!d || !d.isPresent || d.powerSupply || !isPeripheral(d.type))
                continue;
            const pct = Math.round(d.percentage * 100);
            out.push({
                name: d.model && d.model.length > 0 ? d.model : "device",
                pct: pct,
                glyph: root.glyphFor(d.type),
                low: pct <= root.lowThreshold
            });
        }
        return out;
    }

    // Solaar-parsed devices (no type info from the text dump, so a mouse glyph).
    property var solaarDevices: []

    // UPower is authoritative; solaar only fills in when UPower shows nothing.
    readonly property var devices: upowerDevices.length > 0 ? upowerDevices : root.solaarDevices
    readonly property bool hasDevices: devices.length > 0

    // Lowest charge among peripherals — drives the bar glyph colour.
    readonly property int lowest: {
        let m = 100;
        for (let i = 0; i < devices.length; i++)
            if (devices[i].pct >= 0 && devices[i].pct < m)
                m = devices[i].pct;
        return m;
    }
    readonly property bool anyLow: hasDevices && lowest <= lowThreshold

    // Fallback probe: solaar is a heavy Python process, so poll at 300s like
    // omarchy-mouse-battery, not the 5s cadence of the native bar bindings. Only
    // armed while UPower reports no peripheral; otherwise the cached list is dropped.
    readonly property var solaarProbe: Process {
        id: solaarProbe
        command: [Config.solaar, "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = Peripherals.parseSolaarShow(text);
                root.solaarDevices = parsed.map(d => ({
                            "name": d.name,
                            "pct": d.pct,
                            "glyph": "󰍽",
                            "low": d.pct <= root.lowThreshold
                        }));
            }
        }
    }

    readonly property var solaarPoll: Timer {
        interval: 300000
        running: Style.peripheralsFallback
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.upowerDevices.length === 0)
                solaarProbe.running = true;
            else
                root.solaarDevices = [];
        }
    }
}
