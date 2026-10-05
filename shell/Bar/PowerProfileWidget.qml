import Quickshell.Services.UPower
import qs.Ui
import qs.Commons
import qs.Services

// Power profile indicator, mirroring waybar's power-profiles-daemon widget: a
// pure view over Services/PowerProfileState (click = cycle).
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
    tooltipText: "Power profile: " + PowerProfileState.name
    onClicked: PowerProfileState.cycle()
}
