// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Ui` / `qs.Commons` imports (-> `qs.compat.*`) and `Color.` reads (->
// `CompatColor.`) are rewritten; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick

// The search line of a keyboard-driven panel. It is a TextInput because Qt
// hands input-method text (fcitx5 composing Japanese, Chinese or Korean) only
// to text-input items; a Text fed by Keys.onPressed never receives it.
TextInput {
  id: root

  // Sees every key first; whatever it leaves unaccepted is typed here.
  property Item keyHandler: null

  focus: true
  clip: true
  Keys.priority: Keys.BeforeItem
  Keys.forwardTo: keyHandler ? [keyHandler] : []
  // Alt and Super chords are shortcuts, never text.
  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) event.accepted = true
  }

  // Append-only: the panel owns Left and Right, so the caret stays hidden at
  // the end. An empty delegate holds it hidden; cursorVisible returns on focus.
  cursorDelegate: Item {}
  onCursorPositionChanged: if (cursorPosition !== length) cursorPosition = length
  onSelectedTextChanged: if (selectedText) deselect()
}
