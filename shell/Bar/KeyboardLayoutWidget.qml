import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Active keyboard layout: a pure view over Services/KeyboardLayout, which owns
// the one startup probe and the one Hyprland `activelayout` subscription for the
// seat (the widget is instantiated once per monitor). Hidden until a layout is
// known so it never shows a stray placeholder.
BarItem {
    id: root

    shown: KeyboardLayout.code.length > 0
    interactive: true
    text: KeyboardLayout.code
    textColor: Color.textMuted
    tooltipText: KeyboardLayout.keymap

    onClicked: KeyboardLayout.cycle()
}
