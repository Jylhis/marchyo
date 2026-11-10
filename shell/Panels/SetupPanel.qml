import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// First-login checklist built from `marchyo setup`. Each open item has a Fix
// button that runs the CLI's fix command; Refresh re-checks after a fix.
Panel {
    id: root

    panelId: "setup"
    title: I18n.t("setup.title")

    onVisibleChanged: {
        if (visible)
            Setup.refresh();
    }

    function mark(status: string): string {
        return status === "done" ? "" : status === "todo" ? "" : "";
    }

    body: [
        PanelHero {
            iconText: ""
            title: I18n.t("setup.hero")
            subtitle: Setup.loaded ? (Setup.todoCount > 0 ? I18n.tn("setup.todo", Setup.todoCount, Setup.todoCount) : I18n.t("setup.allDone")) : ""
        },
        Repeater {
            model: Setup.items

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.spacing

                Text {
                    text: root.mark(modelData.status)
                    color: modelData.status === "done" ? Colors.statusOk : modelData.status === "todo" ? Colors.accent : Colors.textFaint
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: modelData.status === "skip" ? Colors.textFaint : Colors.textHeading
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: modelData.detail || ""
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                PanelButton {
                    visible: modelData.status === "todo" && !!modelData.fix
                    text: modelData.fix ? modelData.fix.label : ""
                    onClicked: Setup.fix(modelData)
                }
            }
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            PanelButton {
                text: I18n.t("setup.refresh")
                onClicked: Setup.refresh()
            }
            Item {
                Layout.fillWidth: true
            }
            PanelButton {
                text: I18n.t("setup.done")
                onClicked: {
                    Setup.finish();
                    PanelManager.close();
                }
            }
        }
    ]
}
