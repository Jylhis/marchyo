import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// Notification do-not-disturb indicator. Mirrors waybar's custom/dnd: reads mako's
// mode (`makoctl mode` lists "do-not-disturb" when silenced); click toggles via
// the marchyo CLI, then re-probes.
BarItem {
  id: root

  property bool dnd: false

  interactive: true
  text: dnd ? "dnd" : "notif"
  textColor: dnd ? Color.statusErr : Color.textMuted

  Process {
    id: probe
    command: [ Config.makoctl, "mode" ]
    stdout: StdioCollector {
      onStreamFinished: root.dnd = text.indexOf("do-not-disturb") !== -1
    }
  }

  Process {
    id: toggle
    command: [ Config.marchyo, "toggle", "notifications" ]
    onExited: probe.running = true
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: probe.running = true
  }

  onClicked: toggle.running = true
}
