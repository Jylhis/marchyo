import qs.Ui
import qs.Commons

// Runtime theme indicator + cycler. Commons/Theme owns the one colors.json
// read behind the current-theme pointer and the `marchyo theme next`
// toggle; the widget is a pure view (moon = dark active, sun = light).
// Hidden while no reading exists (no marchyo desktop / theme manifest).
BarItem {
    id: root

    interactive: true
    visible: Theme.known
    text: Theme.variant === "light" ? "󰖙" : "󰖔"
    textColor: Color.textMuted
    tooltipText: Theme.name.length > 0 ? "Theme: " + Theme.name + " — click to cycle" : "Cycle theme"

    onClicked: Theme.toggle()
}
