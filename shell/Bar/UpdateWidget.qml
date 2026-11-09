import qs.Ui
import qs.Commons
import qs.Services

// Update indicator: a pure view over Services/Updates. Hidden until the flake
// lock pins a newer nixpkgs than the running system. It only reports: the user
// rebuilds on purpose. Registered but not placed by default: add marchyo.update to a bar section.
BarItem {
    id: root

    compact: true
    shown: Updates.available
    text: "󰚰"
    textColor: Colors.accent
    tooltipText: I18n.t("update.available")
}
