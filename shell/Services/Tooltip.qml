pragma Singleton
import QtQuick
import QtQuick.Window

// Shared tooltip state: BarItem (and the tray icons) hand over the text plus
// their position on hover; the one Ui/TooltipWindow surface renders it anchored
// below the bar on the hovered item's screen. A plain qs.Services singleton so
// every bar consumer agrees without a window of its own.
QtObject {
    id: root

    property string text: ""
    // Scene-x of the hovered item's center — screen-local for the top bar (its
    // layer surface spans the output from the top-left). Recomputed at hover time.
    property real anchorX: 0
    // Name of the screen the hovered item lives on (QScreen.name via the
    // attached Window.window, which matches QsScreen.name for the lookup).
    property string screenName: ""
    readonly property bool active: text.length > 0 && anchorX >= 0

    // Call from any item's hover handler; resolves the position and screen.
    // Defensive: if the attached Window.window cannot be resolved for the item
    // (or its screen is unknown), the tooltip still shows on the default screen.
    function show(text: string, item) {
        if (!item || text.length === 0)
            return;
        root.text = text;
        try {
            const w = item.Window.window;
            root.screenName = w && w.screen ? w.screen.name : "";
        } catch (e) {
            root.screenName = "";
        }
        root.anchorX = item.mapToItem(null, item.width / 2, 0).x;
    }

    function hide() {
        root.text = "";
        root.anchorX = 0;
        root.screenName = "";
    }
}
