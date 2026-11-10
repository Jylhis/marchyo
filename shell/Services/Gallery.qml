pragma Singleton
import QtQuick

// Which section of the dev gallery panel to show ("" = the section index).
// Set by `marchyo shell gallery [section]` before the panel opens.
QtObject {
    property string section: ""
}
