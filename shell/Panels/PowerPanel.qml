import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Format.js" as Format

Panel {
    id: root
    panelId: "power"
    title: I18n.t("power.title")

    readonly property var dev: Power.dev
    readonly property bool hasBattery: Power.hasBattery
    readonly property int pct: Power.pct

    function fmtTime(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? I18n.t("power.durationHoursMinutes", h, m) : I18n.t("power.durationMinutes", m);
    }

    property int lastTimeLeft: 0
    property int lastTimeFull: 0
    Connections {
        target: Power
        function onPctLeftChanged() {
            if (Power.pctLeft > 0)
                root.lastTimeLeft = Power.pctLeft;
        }
        function onPctFullChanged() {
            if (Power.pctFull > 0)
                root.lastTimeFull = Power.pctFull;
        }
    }

    readonly property string stateText: Power.holding ? I18n.t("power.holding") : Power.full ? I18n.t("power.batteryFull", pct) : Power.charging ? I18n.t("power.batteryCharging", pct) : I18n.t("power.batteryOnBattery", pct)

    component Muted: Text {
        Layout.fillWidth: true
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    component Line: Text {
        Layout.fillWidth: true
        color: Colors.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        elide: Text.ElideRight
    }

    component Warning: Line {
        color: Colors.statusWarn
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    body: [
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasBattery
            Line {
                text: Power.glyph
                font.pixelSize: Style.fontSize * 3
                color: Power.barColor
            }
            Line {
                text: I18n.formatNumber(root.pct) + "%"
                font.pixelSize: Style.fontSize * 2
                horizontalAlignment: Text.AlignRight
            }
        },
        Line {
            text: root.hasBattery ? root.stateText : I18n.t("power.noBattery")
        },
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 12
            visible: root.hasBattery
            radius: height / 2
            color: Colors.bgSubtle
            Rectangle {
                id: fill
                width: parent.width * Math.max(0, Math.min(100, root.pct)) / 100
                height: parent.height
                radius: parent.radius
                color: Power.barColor
                Behavior on width {
                    enabled: !Style.reduceMotion
                    NumberAnimation {
                        duration: Style.duration(320)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    enabled: !Style.reduceMotion
                    ColorAnimation {
                        duration: Style.duration(220)
                    }
                }
                SequentialAnimation on opacity {
                    running: root.visible && Power.charging && !Power.holding && !Style.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.6
                        duration: Style.duration(480)
                    }
                    NumberAnimation {
                        to: 1
                        duration: Style.duration(480)
                    }
                    onRunningChanged: {
                        if (!running)
                            fill.opacity = 1;
                    }
                }
            }
        },
        GridLayout {
            Layout.fillWidth: true
            visible: root.hasBattery
            columns: 2
            Muted {
                text: I18n.t(Power.charging ? "power.timeToFull" : "power.timeLeft")
            }
            Line {
                horizontalAlignment: Text.AlignRight
                text: Power.holding ? I18n.t("power.holding") : Power.full ? "" : root.fmtTime(Power.charging ? (Power.pctFull || root.lastTimeFull) : (Power.pctLeft || root.lastTimeLeft))
            }
            Muted {
                text: I18n.t("power.rate")
            }
            Line {
                horizontalAlignment: Text.AlignRight
                text: Format.fmtWatts(Power.rate) || I18n.t("power.idle")
            }
            Muted {
                text: I18n.t("power.capacity")
            }
            Line {
                horizontalAlignment: Text.AlignRight
                text: I18n.formatNumber(Power.energyWh, 1) + " / " + I18n.formatNumber(Power.capacityWh, 1) + " Wh"
            }
            Muted {
                visible: Power.chargerW > 0
                text: I18n.t("power.chargerLabel")
            }
            Line {
                visible: Power.chargerW > 0
                horizontalAlignment: Text.AlignRight
                text: I18n.formatNumber(Power.chargerW) + " W"
            }
        },
        Warning {
            visible: Power.drainingOnAc
            text: I18n.t("power.drainingOnAc", Format.fmtWatts(Power.rate))
        },
        Muted {
            text: I18n.t("power.profile")
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            PanelButton {
                id: saver
                Layout.fillWidth: true
                iconText: "󰌪"
                KeyNavigation.right: balanced
                text: I18n.t("power.profileEco")
                active: PowerProfileState.profile === PowerProfile.PowerSaver
                onClicked: PowerProfileState.setProfile(PowerProfile.PowerSaver)
            }

            PanelButton {
                id: balanced
                Layout.fillWidth: true
                iconText: "󰊚"
                KeyNavigation.left: saver
                KeyNavigation.right: performance.visible ? performance : saver
                text: I18n.t("power.profileBalanced")
                active: PowerProfileState.profile === PowerProfile.Balanced
                onClicked: PowerProfileState.setProfile(PowerProfile.Balanced)
            }

            PanelButton {
                id: performance
                Layout.fillWidth: true
                visible: PowerProfileState.hasPerformance
                iconText: "󰓅"
                KeyNavigation.left: balanced
                text: I18n.t("power.profilePerformance")
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
            text: I18n.t("power.menu")
            onClicked: {
                if (PluginIndex.replacementFor("launcher") !== "") {
                    PanelManager.close();
                    Launcher.openMenu("system");
                } else if (Style.menusEnabled) {
                    Quickshell.execDetached([Config.terminal, "--class=org.omarchy.terminal", "-e", Config.marchyo, "menu", "power"]);
                } else {
                    Launcher.toggle("apps");
                }
            }
        },
        PanelButton {
            Layout.fillWidth: true
            text: I18n.t("power.rollback")
            onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.terminal", "-e", Config.bash, "-c", Config.marchyo + " rollback; read -rn1 -p 'Press any key'"])
        }
    ]
}
