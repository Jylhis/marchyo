pragma Singleton
import QtQuick
import Quickshell.Services.UPower
import qs.Commons

// Shared power-profile state over power-profiles-daemon (UPower's
// PowerProfiles). Read by the bar's PowerProfileWidget, the power panel and
// the Control Center tile; writes go straight to the daemon over D-Bus.
QtObject {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    readonly property string name: {
        switch (root.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }

    readonly property string label: {
        switch (root.profile) {
        case PowerProfile.PowerSaver:
            return I18n.t("power.nameSaver");
        case PowerProfile.Performance:
            return I18n.t("power.namePerformance");
        default:
            return I18n.t("power.nameBalanced");
        }
    }

    function setProfile(p: int): void {
        if (p === PowerProfile.Performance && !root.hasPerformance)
            return;
        PowerProfiles.profile = p;
    }

    // power-saver -> balanced -> performance -> power-saver; performance is
    // skipped on hardware that does not offer it.
    function cycle(): void {
        switch (root.profile) {
        case PowerProfile.PowerSaver:
            root.setProfile(PowerProfile.Balanced);
            break;
        case PowerProfile.Balanced:
            root.setProfile(root.hasPerformance ? PowerProfile.Performance : PowerProfile.PowerSaver);
            break;
        default:
            root.setProfile(PowerProfile.PowerSaver);
        }
    }
}
