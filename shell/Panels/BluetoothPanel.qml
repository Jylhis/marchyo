import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services

Panel {
    id: root
    panelId: "bluetooth"
    title: I18n.t("bluetooth.title")
    property bool scanRegistered: false

    onVisibleChanged: {
        if (visible && !root.scanRegistered) {
            root.scanRegistered = true;
            BluetoothState.acquireScan();
        } else if (!visible && root.scanRegistered) {
            root.scanRegistered = false;
            BluetoothState.releaseScan();
        }
    }
    Component.onDestruction: {
        if (root.scanRegistered)
            BluetoothState.releaseScan();
    }

    body: [
        PanelSectionHeader {
            text: {
                if (!BluetoothState.enabled)
                    return "󰂲 " + I18n.t("bluetooth.off");
                const count = BluetoothState.connected.length;
                return "󰂯 " + I18n.tn("bluetooth.connectionCount", count, count);
            }
        },
        Text {
            Layout.fillWidth: true
            visible: !BluetoothState.available || !BluetoothState.enabled
            text: !BluetoothState.available ? I18n.t("bluetooth.unavailable") : I18n.t("bluetooth.turnOn")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.WordWrap
        },
        Toggle {
            Layout.fillWidth: true
            visible: BluetoothState.available
            label: I18n.t("bluetooth.power")
            checked: BluetoothState.enabled
            onToggled: value => BluetoothState.setEnabled(value)
        },
        Toggle {
            Layout.fillWidth: true
            visible: BluetoothState.enabled
            label: I18n.t("bluetooth.scan")
            description: BluetoothState.scanning ? I18n.t("bluetooth.scanning") : ""
            checked: BluetoothState.scanning
            onToggled: value => BluetoothState.setScanning(value)
        },
        Text {
            Layout.fillWidth: true
            visible: BluetoothState.enabled && BluetoothState.sections.length === 0
            text: BluetoothState.scanning ? I18n.t("bluetooth.scanning") : I18n.t("bluetooth.none")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        Flickable {
            id: scroll
            visible: BluetoothState.enabled
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(groups.implicitHeight, Math.max(120, root.height - Style.barHeight - Style.panelPad * 8 - Style.panelRowHeight * 4))
            contentWidth: width
            contentHeight: groups.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property var focusedItem: Window.activeFocusItem
            onFocusedItemChanged: Qt.callLater(ensureFocusVisible)

            function ensureFocusVisible(): void {
                let item = focusedItem;
                while (item && item !== groups)
                    item = item.parent;
                if (!item || !focusedItem)
                    return;
                const point = focusedItem.mapToItem(groups, 0, 0);
                const bottom = point.y + focusedItem.height;
                if (point.y < contentY)
                    contentY = Math.max(0, point.y);
                else if (bottom > contentY + height)
                    contentY = Math.min(Math.max(0, contentHeight - height), bottom - height);
            }

            ColumnLayout {
                id: groups
                width: scroll.width
                spacing: Style.spacing
                Repeater {
                    model: BluetoothState.enabled ? BluetoothState.sections : []
                    ColumnLayout {
                        id: section
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Style.spacing

                        PanelSectionHeader {
                            text: I18n.t("bluetooth.section." + section.modelData.key)
                        }
                        Repeater {
                            model: section.modelData.rows
                            RowLayout {
                                id: deviceRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Style.spacing

                                function forget(): void {
                                    BluetoothState.forget(deviceRow.modelData);
                                }

                                PanelActionButton {
                                    id: action
                                    Layout.fillWidth: true
                                    iconText: deviceRow.modelData.connected ? "󰂱" : "󰂯"
                                    text: deviceRow.modelData.name
                                    hint: {
                                        const row = deviceRow.modelData;
                                        if (row.status)
                                            return I18n.t("bluetooth.pending." + row.status);
                                        if (row.battery)
                                            return row.battery;
                                        if (row.connected)
                                            return I18n.t("bluetooth.deviceConnected");
                                        return row.paired ? "" : I18n.t("bluetooth.pair");
                                    }
                                    onClicked: BluetoothState.activate(deviceRow.modelData)
                                    Keys.onRightPressed: e => {
                                        if (forgetButton.visible)
                                            forgetButton.forceActiveFocus(Qt.TabFocusReason);
                                        e.accepted = true;
                                    }
                                    Keys.onPressed: e => {
                                        if (e.key === Qt.Key_Delete || e.key === Qt.Key_X)
                                            deviceRow.forget();
                                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                                            BluetoothState.activate(deviceRow.modelData);
                                        else
                                            return;
                                        e.accepted = true;
                                    }
                                }
                                PanelButton {
                                    id: forgetButton
                                    visible: deviceRow.modelData.paired
                                    enabled: !deviceRow.modelData.busy
                                    text: I18n.t("bluetooth.forget")
                                    textColor: Colors.statusErr
                                    onClicked: deviceRow.forget()
                                    Keys.onLeftPressed: e => {
                                        action.forceActiveFocus(Qt.BacktabFocusReason);
                                        e.accepted = true;
                                    }
                                    Keys.onPressed: e => {
                                        if (e.key === Qt.Key_Delete || e.key === Qt.Key_X || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                                            deviceRow.forget();
                                        else
                                            return;
                                        e.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    ]
}
