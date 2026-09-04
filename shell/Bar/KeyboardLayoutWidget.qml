import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Active keyboard layout, mirroring waybar's hyprland/language "{short}": a pure
// view over Services/KeyboardLayout, which owns the one startup probe and the one
// Hyprland `activelayout` subscription for the seat (the widget itself is
// instantiated once per monitor). Click cycles layouts (a no-op on single-layout
// hosts). Hidden until a layout is known so it never shows a stray placeholder.
BarItem {
    id: root

    visible: KeyboardLayout.code.length > 0
    interactive: true
    text: KeyboardLayout.code
    textColor: Color.textMuted
    // waybar's tooltip-format "{long}": the full keymap name.
    tooltipText: KeyboardLayout.keymap

    onClicked: KeyboardLayout.cycle()
}
