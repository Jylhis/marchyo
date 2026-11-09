import qs.Ui
import qs.Commons

// Runtime theme indicator + cycler. Commons/Theme owns the one colors.json
// read behind the current-theme pointer and the `marchyo theme next` toggle;
// the widget is a pure view. Hidden while no reading exists (no marchyo desktop
// or theme manifest).
BarItem {
    id: root

    interactive: true
    shown: Theme.known
    compact: true
    text: Theme.variant === "light" ? "󰖙" : "󰖔"
    textColor: Colors.textMuted
    tooltipText: Theme.name.length > 0 ? I18n.t("theme.tooltipNamed", Theme.name) : I18n.t("theme.tooltipCycle")

    onClicked: Theme.toggle()
}
