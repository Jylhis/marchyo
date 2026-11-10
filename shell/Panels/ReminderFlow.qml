import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/ReminderFlow.js" as Flow

Panel {
    id: root
    panelId: "reminders"
    title: I18n.t("reminders.title")
    centered: true
    keyboardFocus: WlrKeyboardFocus.OnDemand

    property real minutes: 0
    readonly property string step: root.minutes === 0 ? "minutes" : "message"

    function submit(): void {
        if (root.minutes === 0) {
            const count = Flow.minutes(input.text);
            if (count === 0) {
                Reminders.invalidMinutes();
                return;
            }
            root.minutes = count;
            input.clear();
            input.focusInput();
        } else if (Reminders.schedule(root.minutes, input.text)) {
            PanelManager.close();
        }
    }

    onVisibleChanged: {
        root.minutes = 0;
        input.clear();
        if (visible)
            Qt.callLater(input.focusInput);
    }

    body: [
        Text {
            Layout.fillWidth: true
            text: {
                if (root.minutes === 0)
                    return I18n.t("reminders.minutesPrompt");
                return I18n.t("reminders.messagePrompt", root.minutes);
            }
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.WordWrap
        },
        FilterInput {
            id: input
            Layout.fillWidth: true
            placeholderText: I18n.t("reminders." + root.step + "Placeholder")
            onSubmitted: root.submit()
        },
        PanelButton {
            Layout.alignment: Qt.AlignRight
            text: I18n.t(root.minutes === 0 ? "reminders.next" : "reminders.schedule")
            onClicked: root.submit()
        }
    ]
}
