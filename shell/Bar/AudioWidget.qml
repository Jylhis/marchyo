import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

// Default-sink volume. Scroll to adjust, right-click to mute — matches waybar's
// wireplumber widget (scroll-step 5, max-volume 150). Left-click opens the
// mixer (wired in a later step alongside the other TUI launches).
BarItem {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null

  // Without an object tracker the node's audio properties never bind/update.
  PwObjectTracker {
    objects: root.sink ? [ root.sink ] : []
  }

  interactive: true
  text: audio
    ? (audio.muted ? "vol mute" : "vol " + Math.round(audio.volume * 100) + "%")
    : "vol"
  textColor: (audio && audio.muted) ? Color.textFaint : Color.text

  onWheel: (delta) => {
    if (!audio) return;
    audio.volume = Math.max(0.0, Math.min(1.5, audio.volume + (delta > 0 ? 0.05 : -0.05)));
  }
  onRightClicked: () => {
    if (audio) audio.muted = !audio.muted;
  }
}
