// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Ui` / `qs.Commons` imports (-> `qs.compat.*`) and `Color.` reads (->
// `CompatColor.`) are rewritten; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick

// Detached widget-catalogue snapshot for third-party full-bar implementations.
// Plugins can render the referenced components, but mutating this local view
// cannot replace a registration in the host registry.
QtObject {
  id: api

  property var widgets: ({})
  property int revision: 0

  function metadataFor(id) {
    var entry = widgets[String(id || "")]
    return entry ? entry.metadata : null
  }

  function availableIds() {
    return Object.keys(widgets)
  }

  function has(id) {
    return widgets[String(id || "")] !== undefined
  }
}
