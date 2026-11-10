import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// The service shares keyboard selection and recovery across monitors.
BarItem {
    id: root

    shown: KeyboardLayout.multiple && KeyboardLayout.code.length > 0
    interactive: true
    text: KeyboardLayout.code
    textColor: Colors.textMuted
    tooltipText: KeyboardLayout.keymap

    onClicked: KeyboardLayout.cycle()
}
