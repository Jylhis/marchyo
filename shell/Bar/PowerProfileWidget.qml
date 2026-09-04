import Quickshell.Services.UPower
import qs.Ui
import qs.Commons

// Power profile indicator. Left-click cycles saver → balanced → performance,
// mirroring waybar's power-profiles-daemon widget (native cycle on click).
BarItem {
    interactive: true
    text: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "󰾆";
        case PowerProfile.Performance:
            return "󰓇";
        default:
            return "󰾅";
        }
    }
    tooltipText: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "Power profile: power-saver";
        case PowerProfile.Performance:
            return "Power profile: performance";
        default:
            return "Power profile: balanced";
        }
    }
    onClicked: () => {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            PowerProfiles.profile = PowerProfile.Balanced;
            break;
        case PowerProfile.Balanced:
            PowerProfiles.profile = PowerProfile.Performance;
            break;
        default:
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }
}
