// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Commons` import is rewritten to `qs.compat.Commons`; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick
import Quickshell.Io
import qs.compat.Commons

// Base item for plugin popup widgets. Many first-party plugins expose a bar
// button plus a popup from one QML entry point; this base owns the shared
// IPC-backed open/close lifecycle while implementations own button behavior,
// keyboard navigation, and content.
Item {
    id: root

    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})
    property string ipcTarget: ""
    property bool manageIpc: true
    property alias controller: panelController
    property bool popoutSwitching: false
    property bool popoutSwitchClosing: false

    readonly property bool opened: panelController.open
    readonly property color barForeground: bar ? bar.barForeground : Color.foreground

    function open() {
        panelController.show();
    }
    function close() {
        panelController.hide();
    }
    function closeForPopoutSwitch() {
        popoutSwitchClosing = true;
        close();
        Qt.callLater(function () {
            popoutSwitchClosing = false;
        });
    }
    function toggle() {
        opened ? close() : open();
    }
    function switchPanel(direction) {
        if (bar && typeof bar.switchPanelFrom === "function")
            return bar.switchPanelFrom(root, direction);
        return false;
    }

    // Inline shell.json value with fallback. Matches BarWidget.setting().
    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    PanelController {
        id: panelController
    }

    ShellIpc {
        enabled: root.manageIpc && root.ipcTarget !== ""
        target: root.ipcTarget

        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function show(): void {
            root.open();
        }
        function hide(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
