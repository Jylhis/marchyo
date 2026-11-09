import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// What changed: the NEWS entries that arrived since the user last looked, and a
// short dix summary of the last switch. Closing the panel marks them seen.
Panel {
    id: root

    panelId: "whatsnew"
    title: I18n.t("whatsnew.title")

    onVisibleChanged: {
        if (visible)
            WhatsNew.refresh();
        else
            WhatsNew.markSeen();
    }

    body: [
        PanelHero {
            iconText: "1"
            title: I18n.t("whatsnew.hero")
            subtitle: WhatsNew.loaded ? I18n.tn("whatsnew.entries", WhatsNew.entries.length, WhatsNew.entries.length) : ""
        },
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(column.implicitHeight, Style.notifCenterMaxHeight)
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            activeFocusOnTab: true

            Keys.onPressed: e => {
                const page = scroll.height * 0.9;
                let to = scroll.contentY;
                if (e.key === Qt.Key_Down)
                    to += Style.fontSize * 3;
                else if (e.key === Qt.Key_Up)
                    to -= Style.fontSize * 3;
                else if (e.key === Qt.Key_PageDown)
                    to += page;
                else if (e.key === Qt.Key_PageUp)
                    to -= page;
                else
                    return;
                const max = Math.max(0, scroll.contentHeight - scroll.height);
                const atEdge = (e.key === Qt.Key_Down && scroll.contentY >= max) || (e.key === Qt.Key_Up && scroll.contentY <= 0);
                if (atEdge)
                    return;
                scroll.contentY = Math.max(0, Math.min(max, to));
                e.accepted = true;
            }

            ColumnLayout {
                id: column
                width: scroll.width
                spacing: Style.spacing

                Text {
                    Layout.fillWidth: true
                    visible: WhatsNew.loaded && WhatsNew.entries.length === 0
                    text: I18n.t("whatsnew.empty")
                    color: Colors.textFaint
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }

                Repeater {
                    model: WhatsNew.entries

                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        color: Colors.text
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                    }
                }

                PanelSectionHeader {
                    visible: WhatsNew.summary.length > 0
                    text: I18n.t("whatsnew.lastSwitch")
                }

                Text {
                    Layout.fillWidth: true
                    visible: WhatsNew.summary.length > 0
                    text: WhatsNew.summary.join("\n")
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        },
        PanelActionButton {
            Layout.fillWidth: true
            iconText: ""
            text: I18n.t("whatsnew.close")
            onClicked: PanelManager.close()
        }
    ]
}
