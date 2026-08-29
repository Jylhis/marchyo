import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Services

// Default-sink volume. Scroll to adjust, right-click to mute, left-click opens the
// in-shell audio panel (output picker + volume/mute, with a wiremix escape hatch).
// Scroll-step 5, max-volume 150, matching waybar's wireplumber widget. The
// default sink is shared with the panel and the OSD via Services/Audio.
BarItem {
    id: root

    readonly property var sink: Audio.sink
    readonly property var audio: Audio.sinkAudio

    interactive: true
    text: audio ? (audio.muted ? "vol mute" : "vol " + Math.round(audio.volume * 100) + "%") : "vol"
    textColor: (audio && audio.muted) ? Color.textFaint : Color.text
    // Waybar parity ("Playing at N%") plus the sink name for context.
    tooltipText: {
        if (!sink)
            return "";
        const name = sink.description || sink.nickname || sink.name || "";
        const level = audio && !audio.muted ? Math.round(audio.volume * 100) + "%" : "muted";
        return name.length > 0 ? (name + "  " + level) : level;
    }

    onWheel: delta => {
        if (!audio)
            return;
        audio.volume = Math.max(0.0, Math.min(1.5, audio.volume + (delta > 0 ? 0.05 : -0.05)));
    }
    onRightClicked: () => {
        if (audio)
            audio.muted = !audio.muted;
    }
    onClicked: PanelManager.toggle("audio")
}
