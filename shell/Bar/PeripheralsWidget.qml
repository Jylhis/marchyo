import qs.Ui
import qs.Commons
import qs.Services

// Wireless-peripheral battery readout: a pure view over Services/Peripherals,
// which aggregates UPower.devices (plus the optional solaar fallback) for the
// seat. Warning/critical thresholds mirror the main BatteryWidget (20% / 10%).
BarItem {
    id: root

    readonly property var lowDevice: {
        const ds = Peripherals.devices;
        if (ds.length === 0)
            return null;
        let low = ds[0];
        for (let i = 1; i < ds.length; i++)
            if (ds[i].pct >= 0 && ds[i].pct < low.pct)
                low = ds[i];
        return low;
    }

    shown: Peripherals.hasDevices
    text: lowDevice ? (lowDevice.glyph + " " + lowDevice.pct) : ""
    textColor: Peripherals.lowest <= 10 ? Color.statusErr : (Peripherals.anyLow ? Color.statusWarn : Color.text)
    tooltipText: {
        const ds = Peripherals.devices;
        const parts = [];
        for (let i = 0; i < ds.length; i++)
            parts.push(ds[i].name + " " + ds[i].pct + "%");
        return parts.join("\n");
    }
}
