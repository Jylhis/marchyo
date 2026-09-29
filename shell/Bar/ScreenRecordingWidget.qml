import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Screen-recording indicator: a pure view over Services/ScreenRecording, which
// owns the one probe/toggle pair for the seat (the widget is instantiated once
// per monitor). Hidden unless a recording is running; clicking it stops and
// saves. Ported from omarchy's ScreenRecording indicator.
BarItem {
    id: root

    interactive: true
    visible: ScreenRecording.recording
    text: "󰻂"
    textColor: Color.statusErr
    tooltipText: "Recording — click to stop"

    onClicked: ScreenRecording.toggle()
}
