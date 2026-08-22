import Quickshell.Services.UPower
import qs.Ui

// Power profile indicator. Left-click cycles saver → balanced → performance,
// mirroring waybar's power-profiles-daemon widget (native cycle on click).
BarItem {
  interactive: true
  text: {
    switch (PowerProfiles.profile) {
    case PowerProfile.PowerSaver: return "eco";
    case PowerProfile.Performance: return "perf";
    default: return "bal";
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
