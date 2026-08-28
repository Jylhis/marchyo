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

  visible: Style.dictationIndicator
  interactive: true
  text: "voice"
  textColor: state === "recording" ? Color.statusErr
    : (state === "transcribing" ? Color.accent : Color.textMuted)

  // Long-running --follow stream: one JSON object per state change.
  Process {
    running: root.visible
    command: [ Config.voxtype, "status", "--format", "json", "--follow", "--icon-theme", "nerd-font" ]
    stdout: SplitParser {
      onRead: (line) => {
        try {
          const obj = JSON.parse(line);
          if (obj.class)
            root.state = obj.class;
        } catch (e) {
          // Ignore non-JSON lines.
        }
      }
    }
  }

  onClicked: Quickshell.execDetached([ Config.voxtype, "record", "toggle" ])
}
