import QtQuick
import qs.Services

// The launcher provider interface. A provider turns its `query` into
// `results`; LauncherWindow renders the active provider's results through the
// one Launcher/ResultsView. Services/Launcher routes the query text to a
// provider by mode and prefix; a provider only sees a query (and only does
// work) while it is the active one.
//
// Each result row is a plain object:
//   title      the primary text (an emoji's characters in a grid provider)
//   subtitle   secondary text, shown muted after the title ("" for none)
//   icon       themed icon name ("" for none / the fallback icon)
//   score      ranking score (higher is better; 0 for unranked rows)
//   positions  matched character indices in `title`, for highlighting
//   activate() runs the row's action; it closes the launcher itself
QtObject {
    id: root

    // Provider id Services/Launcher routes to ("apps", "calc", ...).
    property string providerId: ""
    // Query prefix that selects this provider from the apps palette ("" for
    // the IPC modes apps / emoji / clipboard).
    property string prefix: ""

    readonly property bool active: Launcher.open && Launcher.provider === root.providerId
    readonly property string query: root.active ? Launcher.providerQuery : ""

    property var results: []

    // Presentation the shared ResultsView reads.
    property string layout: "list" // "list" | "grid"
    property int columns: 8 // grid only
    property int maxRows: 8 // list only: visible rows before scrolling
    property bool showIcons: true
    property bool compact: false // small font rows
    property bool highlight: true // StyledText title with match highlighting
    // Preselect the first row with an empty query (otherwise only once typed).
    property bool selectOnEmpty: false
    property string emptyText: "no matches"

    // Inline completion: when `completes`, `suggestion` is the full text the
    // query field offers as ghost text (accepted on Tab / Right).
    property bool completes: false
    property string suggestion: ""
}
