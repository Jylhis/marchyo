import QtQuick

// Panel-body pill: a Button with an `active` (selected) state, kept for the
// panels that predate the Ui kit.
Button {
    property bool active: false

    selected: active
}
