import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/MenuModel.js" as MenuModel
import "../Commons/OmarchyMenu.js" as OmarchyMenu
import "../Commons/Paths.js" as Paths

// While omarchy.menu replaces the launcher, keeps omarchy's menu extension
// (~/.config/omarchy/extensions/omarchy-menu.jsonc) equal to the command menu
// tree: menu.json merged per key with menu.local.json, as Launcher/MenuProvider
// merges them, plus the keybinding cheat sheet. The plugin watches that file,
// so it is written in place: an atomic rename would end the plugin's watch.
Item {
    id: root
    visible: false

    readonly property string configHome: Paths.xdgDir(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"), "/.config")
    readonly property string configDir: root.configHome + "/marchyo"
    readonly property string extensionDir: root.configHome + "/omarchy/extensions"

    readonly property string rendered: OmarchyMenu.render(MenuModel.build(MenuModel.mergeOverlay(MenuModel.parseEntries(baseFile.text()), MenuModel.parseEntries(localFile.text()))), MenuModel.parseJson(sheetFile.text()))

    onRenderedChanged: writeTimer.restart()
    Component.onCompleted: writeTimer.restart()

    FileView {
        id: baseFile
        path: root.configDir + "/menu.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: localFile
        path: root.configDir + "/menu.local.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: sheetFile
        path: root.configDir + "/keybindings.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: extensionFile
        path: root.extensionDir + "/omarchy-menu.jsonc"
        blockLoading: true
        printErrors: false
        atomicWrites: false
    }

    Timer {
        id: writeTimer
        interval: 200
        onTriggered: if (!mkdirProc.running)
            mkdirProc.running = true
    }

    Process {
        id: mkdirProc
        command: [Config.mkdir, "-p", root.extensionDir]
        onExited: {
            extensionFile.reload();
            if (extensionFile.text() !== root.rendered)
                extensionFile.setText(root.rendered);
        }
    }
}
