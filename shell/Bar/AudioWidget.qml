import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

// Default-sink volume. Scroll to adjust, right-click to mute, left-click opens the
// wiremix mixer in a floating terminal — matches waybar's wireplumber widget
// (scroll-step 5, max-volume 150, org.omarchy.wiremix class).
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
  onClicked: Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.wiremix", "-e", Config.wiremix ])
}
