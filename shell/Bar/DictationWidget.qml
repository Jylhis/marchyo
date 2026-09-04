import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Dictation (voxtype) indicator. Streams `voxtype status --format json --follow`;
// the JSON `class` (idle/recording/transcribing) drives text colour. Click toggles
// recording. Visibility is baked from marchyo.dictation (Style.dictationIndicator),
// matching waybar's voxtypeIndicator gate.
BarItem {
    id: root

    property string state: "idle"
    // Nerd-font glyph voxtype emits under --icon-theme nerd-font; falls back to a
    // microphone glyph until the first status line arrives.
    property string glyph: ""

    visible: Style.dictationIndicator
    interactive: true
    text: glyph.length > 0 ? glyph : "󰍬"
    textColor: state === "recording" ? Color.statusErr : (state === "transcribing" ? Color.accent : Color.textMuted)
    tooltipText: "Dictation: " + state

    // Long-running --follow stream: one JSON object per state change.
    Process {
        running: root.visible
        command: [Config.voxtype, "status", "--format", "json", "--follow", "--icon-theme", "nerd-font"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const obj = JSON.parse(line);
                    if (obj.class)
                        root.state = obj.class;
                    if (obj.text)
                        root.glyph = obj.text;
                } catch (e) {
                    // Ignore non-JSON lines.
                }
            }
        }
    }

    onClicked: Quickshell.execDetached([Config.voxtype, "record", "toggle"])
}
