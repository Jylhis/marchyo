import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services

// Power profile indicator, mirroring waybar's power-profiles-daemon widget: a
// pure view over Services/PowerProfileState (click = cycle). Tinted with the
// throttle warnings from Services/Throttle while in performance mode.
BarItem {
    interactive: true
    compact: true
    text: {
        switch (PowerProfileState.profile) {
        case PowerProfile.PowerSaver:
            return "󰾆";
        case PowerProfile.Performance:
            return "󰓅";
        default:
            return "󰾅";
        }
    }
    textColor: Throttle.throttled ? Colors.statusWarn : Colors.text
    tooltipText: [I18n.t("power.profileTooltip", PowerProfileState.label)].concat(Throttle.warnings).join("\n")
    onClicked: PowerProfileState.cycle()
}
