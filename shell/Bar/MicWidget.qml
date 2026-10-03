import qs.Ui
import qs.Commons
import qs.Services

// Microphone-in-use privacy indicator: a pure view over Services/Audio, shown
// only while some application is capturing audio (an AudioInStream exists). This
// is a privacy affordance more than an audio control: it makes a hot mic visible.
BarItem {
    id: root

    shown: Audio.micInUse
    interactive: true
    compact: true
    text: "󰍬"
    textColor: Color.statusWarn
    tooltipText: {
        const parts = [];
        for (let i = 0; i < Audio.captureStreams.length; i++)
            parts.push(Audio.streamLabel(Audio.captureStreams[i]));
        return "Microphone in use:\n" + parts.join("\n");
    }

    onClicked: PanelManager.toggle("audio", root)
}
