import QtQuick
import QtQuick.Layouts
import qs.Commons

// A row of mutually exclusive choices. `options` is a list of strings or of
// { value, label } objects; `value` is the chosen option's value. Left and
// Right move the choice while the group has focus.
FocusScope {
    id: root

    property var options: []
    property string value: ""

    signal changed(string value)

    implicitWidth: row.implicitWidth
    implicitHeight: Style.panelRowHeight
    activeFocusOnTab: true

    function valueOf(opt): string {
        return typeof opt === "string" ? opt : String(opt.value);
    }

    function labelOf(opt): string {
        return typeof opt === "string" ? opt : String(opt.label !== undefined ? opt.label : opt.value);
    }

    function indexOfValue(): int {
        for (let i = 0; i < root.options.length; i++)
            if (root.valueOf(root.options[i]) === root.value)
                return i;
        return -1;
    }

    function step(delta: int): void {
        const n = root.options.length;
        if (n === 0)
            return;
        const cur = root.indexOfValue();
        const next = cur < 0 ? 0 : Math.max(0, Math.min(n - 1, cur + delta));
        root.choose(root.valueOf(root.options[next]));
    }

    function choose(v: string): void {
        if (v === root.value)
            return;
        root.value = v;
        root.changed(v);
    }

    Keys.onLeftPressed: e => root.step(-1)
    Keys.onRightPressed: e => root.step(1)

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.options

            Button {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                text: root.labelOf(modelData)
                selected: root.valueOf(modelData) === root.value
                focusable: false
                bordered: true
                onClicked: {
                    root.forceActiveFocus();
                    root.choose(root.valueOf(modelData));
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.activeFocus
        color: "transparent"
        radius: Style.panelRadius
        border.color: Colors.focusRing
        border.width: Style.borderFocus
    }
}
