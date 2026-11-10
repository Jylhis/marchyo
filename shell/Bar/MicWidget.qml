import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Microphone.js" as Microphone

BarIndicator {
    id: root

    readonly property var captures: Audio.captureStreams.filter(n => Microphone.isCapture(n))
    readonly property bool defaultMuted: !!Audio.sourceAudio && Audio.sourceAudio.muted
    indicatorActive: captures.length > 0
    indicatorAvailable: !!Audio.sourceAudio || captures.length > 0
    interactive: true
    compact: true
    text: root.defaultMuted && !root.indicatorActive ? "󰍭" : "󰍬"
    textColor: root.indicatorActive ? Colors.statusWarn : Colors.text
    tooltipText: {
        const parts = [];
        for (let i = 0; i < root.captures.length; i++)
            parts.push(Audio.streamLabel(root.captures[i]));
        const idleKey = root.defaultMuted ? "barIndicators.micMuted" : "barIndicators.micIdle";
        const key = root.indicatorActive ? "mic.inUse" : idleKey;
        return I18n.t(key) + (parts.length > 0 ? "\n" + parts.join("\n") : "");
    }

    onClicked: PanelManager.toggle("audio", root)
    onMiddleClicked: PanelManager.toggle("audio", root)
    onRightClicked: {
        if (Audio.sourceAudio)
            Audio.sourceAudio.muted = !Audio.sourceAudio.muted;
    }
    onWheel: delta => {
        if (Audio.sourceAudio)
            Audio.sourceAudio.volume = Microphone.steppedVolume(Audio.sourceAudio.volume, delta);
    }
}
