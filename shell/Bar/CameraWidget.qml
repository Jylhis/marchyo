import qs.Ui
import qs.Commons
import qs.Services

// Camera-in-use privacy indicator, the video counterpart of MicWidget: a pure
// view over Services/Camera, shown only while some application is capturing
// from a camera.
BarItem {
    shown: Camera.inUse
    compact: true
    text: String.fromCodePoint(0xF05A0)
    textColor: Color.statusWarn
    tooltipText: "Camera in use:\n" + Camera.users.join("\n")
}
