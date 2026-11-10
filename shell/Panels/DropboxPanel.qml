import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// Dropbox sync state and a start/stop switch, from Services/Dropbox. Needs the
// `dropbox` CLI on PATH; without it the panel says so.
Panel {
    id: root
    panelId: "dropbox"
    title: I18n.t("dropbox.title")

    body: [
        Text {
            Layout.fillWidth: true
            visible: Dropbox.probed && !Dropbox.installed
            text: I18n.t("dropbox.notInstalled")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.WordWrap
        },
        Text {
            Layout.fillWidth: true
            visible: Dropbox.installed
            text: (Dropbox.state === "idle" ? "✓ " : Dropbox.state === "syncing" ? "↻ " : Dropbox.state === "stopped" ? "○ " : "") + (Dropbox.detail !== "" ? Dropbox.detail : I18n.t("dropbox.unknown"))
            color: Dropbox.state === "idle" ? Colors.statusOk : Dropbox.state === "syncing" ? Colors.accent : Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            wrapMode: Text.WordWrap
        },
        Toggle {
            Layout.fillWidth: true
            visible: Dropbox.installed
            label: I18n.t("dropbox.running")
            checked: Dropbox.state !== "stopped" && Dropbox.state !== "unknown"
            onToggled: value => Dropbox.setRunning(value)
        }
    ]
}
