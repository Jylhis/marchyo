import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

// Summoned from AudioWidget. Default-sink volume/mute plus an output-device
// picker, all on native Pipewire bindings (the same service the bar widget and
// OSD use). "wiremix" opens the full mixer TUI for anything this doesn't cover.
Panel {
  id: root
  panelId: "audio"
  title: "Audio"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null

  // Real output sinks, excluding per-application stream nodes.
  readonly property var sinks: {
    const out = [];
    const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i];
      if (n && n.isSink && !n.isStream)
        out.push(n);
    }
    return out;
  }

  function sinkLabel(n) {
    return n ? (n.description || n.nickname || n.name) : "No output";
  }

  // Without a tracker the default sink's volume/mute never bind/update.
  PwObjectTracker {
    objects: root.sink ? [ root.sink ] : []
  }

  body: [
    Text {
      Layout.fillWidth: true
      text: root.sinkLabel(root.sink)
      color: Color.textMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSizeSmall
      elide: Text.ElideRight
    },

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing

      Text {
        Layout.preferredWidth: Style.panelWidth / 4
        text: root.audio ? (root.audio.muted ? "muted" : Math.round(root.audio.volume * 100) + "%") : "n/a"
        color: (root.audio && root.audio.muted) ? Color.textFaint : Color.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
      }

      Item {
        Layout.fillWidth: true
      }

      PanelButton {
        text: "-"
        onClicked: {
          if (root.audio)
            root.audio.volume = Math.max(0.0, root.audio.volume - 0.05);
        }
      }

      PanelButton {
        text: "+"
        onClicked: {
          if (root.audio)
            root.audio.volume = Math.min(1.5, root.audio.volume + 0.05);
        }
      }

      PanelButton {
        text: (root.audio && root.audio.muted) ? "unmute" : "mute"
        active: root.audio ? root.audio.muted : false
        onClicked: {
          if (root.audio)
            root.audio.muted = !root.audio.muted;
        }
      }
    },

    Repeater {
      model: root.sinks

      PanelButton {
        required property var modelData
        Layout.fillWidth: true
        text: root.sinkLabel(modelData)
        active: modelData === root.sink
        onClicked: Pipewire.preferredDefaultAudioSink = modelData
      }
    },

    PanelButton {
      Layout.fillWidth: true
      text: "wiremix"
      onClicked: Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.wiremix", "-e", Config.wiremix ])
    }
  ]
}
