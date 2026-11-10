import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

// Dev gallery: every Ui control in every state, one section at a time. Open it
// with `marchyo shell gallery [section]`. It is the visual regression target
// for the Ui kit and the Jylhis control-state tokens in Commons/Style.
Panel {
    id: root
    panelId: "gallery"
    title: Gallery.section.length > 0 ? I18n.t("gallery.title") + " / " + Gallery.section : I18n.t("gallery.title")
    cardWidth: Style.controlCenterWidth

    readonly property var sections: ["states", "buttons", "inputs", "choices", "panel", "popups", "dialogs"]

    property bool toggleOn: true
    property string choiceValue: "Beta"
    property string groupValue: "2"

    function sectionLabel(name: string): string {
        return I18n.t("gallery.section." + name);
    }

    component SwatchLabel: Text {
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    body: [
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === ""
            spacing: Style.spacing

            Repeater {
                model: root.sections

                PanelActionButton {
                    required property string modelData
                    Layout.fillWidth: true
                    text: root.sectionLabel(modelData)
                    hint: modelData
                    onClicked: Gallery.section = modelData
                }
            }
        },
        PanelButton {
            visible: Gallery.section !== ""
            text: "‹ " + I18n.t("gallery.sections")
            onClicked: Gallery.section = ""
        },
        GridLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "states"
            columns: 2
            columnSpacing: Style.spacing
            rowSpacing: Style.spacing

            Repeater {
                model: ["normal", "hover", "focus", "selected", "pressed"]

                ControlSurface {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: Style.tileHeight
                    hot: modelData === "hover"
                    focused: modelData === "focus"
                    selected: modelData === "selected"
                    pressed: modelData === "pressed"

                    SwatchLabel {
                        anchors.centerIn: parent
                        text: I18n.t("gallery.state." + modelData)
                    }
                }
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "buttons"
            spacing: Style.spacing

            PanelSectionHeader {
                text: I18n.t("gallery.button")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing
                Button {
                    text: I18n.t("gallery.normal")
                }
                Button {
                    text: I18n.t("gallery.selected")
                    selected: true
                }
                Button {
                    text: I18n.t("gallery.flat")
                    bordered: false
                }
                Button {
                    text: I18n.t("gallery.disabled")
                    enabled: false
                }
            }
            PanelSectionHeader {
                text: I18n.t("gallery.actions")
            }
            PanelActionButton {
                Layout.fillWidth: true
                iconText: ""
                text: I18n.t("gallery.action")
                hint: "Ctrl+K"
            }
            PanelActionButton {
                Layout.fillWidth: true
                iconText: ""
                text: I18n.t("gallery.destructive")
                destructive: true
            }
            PanelSeparator {}
            PanelHero {
                iconText: ""
                title: I18n.t("gallery.heroTitle")
                subtitle: I18n.t("gallery.heroSubtitle")
                trailing: "42%"
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "inputs"
            spacing: Style.spacing

            TextField {
                Layout.fillWidth: true
                placeholderText: I18n.t("gallery.textPlaceholder")
            }
            TextField {
                Layout.fillWidth: true
                password: true
                text: "12345"
            }
            FilterInput {
                Layout.fillWidth: true
            }
            Toggle {
                Layout.fillWidth: true
                label: I18n.t("gallery.toggle")
                description: I18n.t("gallery.toggleHint")
                checked: root.toggleOn
                onToggled: value => root.toggleOn = value
            }
            PanelSlider {
                Layout.fillWidth: true
                value: 0.4
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "choices"
            spacing: Style.spacing

            ButtonGroup {
                Layout.fillWidth: true
                options: ["1", "2", "3"]
                value: root.groupValue
                onChanged: v => root.groupValue = v
            }
            Dropdown {
                Layout.fillWidth: true
                placeholderText: I18n.t("gallery.pick")
                options: ["Alpha", "Beta", "Gamma"]
                value: root.choiceValue
                onActivated: v => root.choiceValue = v
            }
            SearchableDropdown {
                Layout.fillWidth: true
                placeholderText: I18n.t("gallery.pick")
                options: ["Helsinki", "Hamburg", "Oslo", "Osaka", "Lisbon", "Lagos", "Lima", "Kyiv"]
                value: "Oslo"
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "panel"
            spacing: Style.spacing

            PanelSectionHeader {
                text: I18n.t("gallery.sectionHeader")
            }
            PanelButton {
                Layout.fillWidth: true
                text: I18n.t("gallery.panelButton")
            }
            PanelButton {
                Layout.fillWidth: true
                text: I18n.t("gallery.panelButtonActive")
                active: true
            }
            PanelSeparator {}
        },
        ColumnLayout {
            Layout.fillWidth: true
            visible: Gallery.section === "popups"
            spacing: Style.spacing

            PopupCard {
                Layout.fillWidth: true
                title: I18n.t("gallery.popupTitle")

                PopupMenuRow {
                    Layout.fillWidth: true
                    iconText: ""
                    text: I18n.t("gallery.row")
                    hint: "H"
                }
                PopupMenuRow {
                    Layout.fillWidth: true
                    text: I18n.t("gallery.rowChecked")
                    checked: true
                }
                PopupMenuRow {
                    Layout.fillWidth: true
                    text: I18n.t("gallery.rowDisabled")
                    enabled: false
                }
            }
        },
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.tileHeight * 3
            visible: Gallery.section === "dialogs"

            Button {
                id: openDialog
                anchors.top: parent.top
                text: I18n.t("gallery.openDialog")
                onClicked: dialog.open = true
            }

            ConfirmDialog {
                id: dialog
                title: I18n.t("gallery.dialogTitle")
                message: I18n.t("gallery.dialogMessage")
                destructive: true
            }
        }
    ]
}
