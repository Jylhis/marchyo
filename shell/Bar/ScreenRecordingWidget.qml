import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Screen-recording indicator: a pure view over Services/ScreenRecording, which
// owns the one probe/toggle pair for the seat (the widget is instantiated once
// per monitor).
BarItem {
    id: root

    interactive: true
    visible: ScreenRecording.recording
    compact: true
    text: "󰻂"
    textColor: Color.statusErr
    tooltipText: "Recording — click to stop"

    onClicked: ScreenRecording.toggle()
}
