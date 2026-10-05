import QtQuick
import Quickshell

// The window overview: one OverviewWindow per screen, all driven by the
// Services/Overview singleton (one query and one selection across monitors).
Scope {
    Variants {
        model: Quickshell.screens

        OverviewWindow {
            required property var modelData
            screen: modelData
        }
    }
}
