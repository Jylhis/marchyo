import qs.Ui
import qs.Commons
import qs.Services

// Media (MPRIS) indicator: a pure view over Services/Mpris, which owns the one
// active-player lookup for the seat (the widget is instantiated once per
// monitor). No subprocess, no poll: native Quickshell.Services.Mpris drives it.
BarItem {
    id: root

    readonly property string shortTitle: {
        const t = Mpris.title;
        if (t.length <= Style.mediaMaxChars)
            return t;
        return t.substring(0, Style.mediaMaxChars - 1) + "…";
    }

    visible: Mpris.active
    interactive: true
    text: (Mpris.isPlaying ? "󰎇 " : "󰏤 ") + shortTitle
    textColor: Mpris.isPlaying ? Color.text : Color.textMuted
    tooltipText: {
        if (!Mpris.active)
            return "";
        if (Mpris.artist.length > 0)
            return Mpris.artist + " · " + Mpris.title;
        return Mpris.title;
    }

    onClicked: Mpris.playPause()
    onRightClicked: Mpris.next()
    onWheel: delta => {
        if (delta > 0)
            Mpris.next();
        else
            Mpris.previous();
    }
}
