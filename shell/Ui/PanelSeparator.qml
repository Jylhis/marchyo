import QtQuick
import QtQuick.Layouts
import qs.Commons

// A full-width hairline between groups of rows in a panel.
Rectangle {
    Layout.fillWidth: true
    implicitHeight: Style.borderWidth
    color: Colors.border
}
