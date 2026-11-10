import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Dictation indicator: a pure view over Services/Dictation, which owns
// the one state source for the seat (the widget is
// instantiated once per monitor). Visibility is baked from marchyo.dictation
// (Style.dictationIndicator).
BarIndicator {
    id: root

    indicatorAvailable: Style.dictationIndicator
    indicatorActive: Dictation.state === "recording" || Dictation.state === "transcribing"
    interactive: true
    compact: true
    // Falls back to a microphone glyph until the first status line arrives.
    text: Dictation.glyph.length > 0 ? Dictation.glyph : "󰍬"
    textColor: Dictation.state === "recording" ? Colors.statusErr : (Dictation.state === "transcribing" ? Colors.accent : Colors.textMuted)
    // A dead backend is reported here, not by recolouring the glyph: the colour
    // already means "recording", so spending it on "not answering" would make
    // one state read as another (and the last known state is still the best
    // guess the bar has).
    tooltipText: Dictation.streaming ? I18n.t("dictation.tooltip", I18n.t("dictation.state." + Dictation.state)) : I18n.t("dictation.tooltipDown", I18n.t("dictation.state." + Dictation.state), Dictation.backend)

    onClicked: Dictation.toggle()
}
