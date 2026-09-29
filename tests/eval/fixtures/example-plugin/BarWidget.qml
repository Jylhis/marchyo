import qs.Ui
import qs.Commons

// Minimal example shell plugin bar-widget (test fixture + docs reference).
// A plugin bar-widget is an ordinary BarItem-based view; it reaches the shell's
// singletons through the qs.* namespace of the config root it is loaded into.
BarItem {
    text: "󰽝 hello"
    tooltipText: "example.hello plugin"
}
