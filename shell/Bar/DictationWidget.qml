import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Dictation (voxtype) indicator: a pure view over Services/Dictation, which owns
// the one `voxtype status --follow` subscription for the seat (the widget itself
// is instantiated once per monitor). The JSON `class` drives the text colour;
// click toggles recording. Visibility is baked from marchyo.dictation
// (Style.dictationIndicator), matching waybar's voxtypeIndicator gate.
BarItem {
    id: root

    visible: Style.dictationIndicator
    interactive: true
    // Nerd-font glyph voxtype emits under --icon-theme nerd-font; falls back to a
    // microphone glyph until the first status line arrives.
    text: Dictation.glyph.length > 0 ? Dictation.glyph : "󰍬"
    textColor: Dictation.state === "recording" ? Color.statusErr : (Dictation.state === "transcribing" ? Color.accent : Color.textMuted)
    // A dead stream is reported here, not by recolouring the glyph: the colour
    // already means "recording", so spending it on "voxtype is not answering"
    // would make one state read as another (and the last known state is still
    // the best guess the bar has).
    tooltipText: Dictation.streaming ? "Dictation: " + Dictation.state : "Dictation: " + Dictation.state + " (voxtype not responding)"

    onClicked: Dictation.toggle()
}
