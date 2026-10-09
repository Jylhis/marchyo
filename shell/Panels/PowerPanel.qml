import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Format.js" as Format

// Battery status, wattages and drain-on-AC warning from Services/Power, a
// power-profile selector (Services/PowerProfileState) with performance-mode
// throttle warnings (Services/Throttle). power menu reaches marchyo's session
// actions, or the launcher when menus are disabled.
Panel {
    id: root
    panelId: "power"
    title: "Power"

    readonly property var dev: Power.dev
    readonly property bool hasBattery: Power.hasBattery
    readonly property int pct: Power.pct

    function fmtTime(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    readonly property string batteryLine: {
        if (!hasBattery)
            return "No battery";
        let s = pct + "%";
        if (Power.full) {
            s += " (full)";
        } else if (Power.charging) {
            const t = fmtTime(Power.pctFull);
            s += t.length > 0 ? (" charging, " + t + " to full") : " charging";
        } else {
            const t = fmtTime(Power.pctLeft);
            s += t.length > 0 ? (" (" + t + " left)") : " on battery";
        }
        return s;
    }

    // "12.3 W discharging · 48.2 / 70.0 Wh"; "idle" when no energy flows
    // (full, or held at a charge threshold).
    readonly property string rateLine: {
        const w = Format.fmtWatts(Power.rate);
        let s = w.length === 0 ? "idle" : (w + (Power.charging ? " charging" : " discharging"));
        if (Power.capacityWh > 0)
            s += "  ·  " + Power.energyWh.toFixed(1) + " / " + Power.capacityWh.toFixed(1) + " Wh";
        return s;
    }

    component Muted: Text {
        Layout.fillWidth: true
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    component Line: Text {
        Layout.fillWidth: true
        color: Color.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        elide: Text.ElideRight
    }

    component Warning: Line {
        color: Color.statusWarn
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    body: [
        Line {
            text: root.batteryLine
            color: root.hasBattery && root.pct <= 10 ? Color.statusErr : Color.text
        },
        Line {
            visible: root.hasBattery
            text: "Battery  " + root.rateLine
        },
        Line {
            visible: Power.chargerW > 0
            text: "Charger  " + Power.chargerW + " W"
        },
        Warning {
            visible: Power.drainingOnAc
            text: "󰀦 Plugged in but discharging " + Format.fmtWatts(Power.rate) + ": charger can't keep up"
        },
        Muted {
            text: "Power profile"
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            PanelButton {
                Layout.fillWidth: true
                text: "eco"
                active: PowerProfileState.profile === PowerProfile.PowerSaver
                onClicked: PowerProfileState.setProfile(PowerProfile.PowerSaver)
            }

            PanelButton {
                Layout.fillWidth: true
                text: "bal"
                active: PowerProfileState.profile === PowerProfile.Balanced
                onClicked: PowerProfileState.setProfile(PowerProfile.Balanced)
            }

            PanelButton {
                Layout.fillWidth: true
                visible: PowerProfileState.hasPerformance
                text: "perf"
                active: PowerProfileState.profile === PowerProfile.Performance
                onClicked: PowerProfileState.setProfile(PowerProfile.Performance)
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Throttle.throttled
            spacing: 0

            Repeater {
                model: Throttle.warnings
                delegate: Warning {
                    required property string modelData
                    text: "󰀦 " + modelData
                }
            }
        },
        PanelButton {
            Layout.fillWidth: true
            text: "power menu"
            onClicked: Style.menusEnabled ? Quickshell.execDetached([Config.terminal, "--class=org.omarchy.terminal", "-e", Config.marchyo, "menu", "power"]) : Launcher.toggle("apps")
        }
    ]
}
