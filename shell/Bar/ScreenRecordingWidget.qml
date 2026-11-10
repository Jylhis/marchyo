import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Screen-recording indicator: a pure view over Services/ScreenRecording, which
// owns the one probe/toggle pair for the seat (the widget is instantiated once
// per monitor).
BarIndicator {
    id: root

    interactive: true
    indicatorActive: ScreenRecording.recording
    compact: true
    text: "󰻂"
    textColor: ScreenRecording.recording ? Colors.statusErr : Colors.text
    tooltipText: {
        const key = ScreenRecording.recording ? "recording.stop" : "barIndicators.recordingStart";
        return I18n.t(key);
    }

    onClicked: ScreenRecording.toggle()
}
