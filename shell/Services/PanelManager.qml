pragma Singleton
import QtQuick

// Tracks which summonable panel is currently open. Panels are mutually exclusive
// — opening one closes any other — so the shell shows at most one at a time. This
// is the whole "panel registry": a single shared string, in-process. Bar widgets
// call toggle(id) on click; each Ui/Panel binds its visibility to openId === id.
// No manifest system, no IPC, no plugin discovery (see plans/shell.md).
QtObject {
  // Empty string = nothing open; otherwise the panelId of the open panel.
  property string openId: ""

  function toggle(id) {
    openId = (openId === id) ? "" : id;
  }

  function open(id) {
    openId = id;
  }

  function close() {
    openId = "";
  }
}
