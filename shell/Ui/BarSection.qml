import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../Commons/BarLayout.js" as BarLayout

// One anchored section of the bar (left / center / right): a row of widget
// slots driven by the ShellConfig layout entries for `section`.
//
// Slots collapse with their widget. Every conditional widget reports its own
// visibility through a plain `shown` bool (media with no player, idle mic,
// desktop battery, hidden theme until the first colors.json read, ...), and
// each slot is a wrapper Item whose `visible` follows that `shown`. A hidden
// wrapper is skipped by the layout entirely, spacing included, so no dead gap
// is left where the widget would sit.
//
// The slot must NEVER bind its (or the Loader's) `visible` to the loaded
// item's own `visible`: QQuickLoader writes item.visible from the Loader's
// visibility, so hiding the Loader — or letting an ancestor's `visible` depend
// on the item's `visible` — overwrites the item's own `visible` binding and
// freezes the widget invisible forever, even after its condition turns true
// again (verified against Qt 6 offscreen; it is why a hidden-at-startup widget
// like the theme toggle never reappeared). Reading the independent `shown`
// flag instead keeps the item's own `visible` logic intact, and the Loader is
// left visible at all times.
//
// Separators are cluster-aware: a rule renders only between two clusters that
// both have visible content, and the rules around an empty cluster collapse
// to one. The decision table is Commons/BarLayout.js (pure, node-tested via
// tests/shell/bar-layout-test.js); this component only feeds it the entry ids
// plus each loaded widget's `shown` flag. A stray rule next to a collapsed
// cluster reads as a floating pixel, and before this component existed every
// separator rendered unconditionally.
//
// Visibility is read through the untyped helper below (not `slot.widget.shown`
// inline): qmllint types Repeater delegates as QQuickItem and Loader.item as
// QObject, so direct member access trips missing-property, while the runtime
// objects always have those members. Same indirection applyWidget() uses.
RowLayout {
    id: root

    // Section name into ShellConfig.bar ("left" | "center" | "right").
    property string section: ""
    // Test seam: the offscreen harness injects entries (it has no Nix-baked
    // shell.json and needs separator + hidden-widget cases); null reads the
    // real layout like the live bar.
    property var entriesOverride: null
    // id -> Component: shell.qml's componentFor (first-party map plus
    // plugin bar-widgets). null entries load nothing, as before.
    property var resolve: null
    // (item, entry) -> void: shell.qml's applyWidget (per-monitor screen,
    // per-entry settings, plugin facade). Separators skip it.
    property var configure: null
    // Cap one unbounded widget (the active-window title) at capFraction of
    // barWidth so a long title can never crowd the centered clock. An empty
    // capId disables the cap.
    property string capId: ""
    property real capFraction: 0.25
    property real barWidth: 0

    // BarItem padding (Style.barItemPad) is the only gap between segments.
    spacing: 0

    readonly property var entries: root.entriesOverride || ShellConfig.bar[root.section] || []

    // A loaded widget's `shown` flag, read through an untyped parameter for the
    // reason given in the file comment. A widget with no `shown` property (a
    // compat plugin bar-widget) defaults to shown, so it keeps its slot. The
    // `visible` fallback covers the rare non-BarItem that never gained `shown`.
    function widgetShown(w): bool {
        if (!w)
            return false;
        if (w.shown !== undefined)
            return w.shown === true;
        return w.visible === true;
    }

    // A slot wrapper's content-shown flag, behind an untyped parameter: qmllint
    // types repeater.itemAt() as QQuickItem, which has no `contentShown`.
    function cellShown(cell): bool {
        return cell ? cell.contentShown === true : false;
    }

    // Per-entry separator render decision (true = draw the rule). Reading
    // repeater.count and each slot's `shown` here is what keeps the binding
    // live: any widget flipping `shown` re-runs the computation, and so does a
    // layout change (ShellConfig re-read) through root.entries.
    readonly property var sepShown: {
        const ids = [];
        for (let k = 0; k < root.entries.length; k++)
            ids.push(root.entries[k].id);
        const shown = [];
        for (let k = 0; k < repeater.count; k++)
            shown.push(root.cellShown(repeater.itemAt(k)));
        return BarLayout.separatorVisibility(ids, shown);
    }

    Repeater {
        id: repeater
        model: root.entries

        // The slot is a wrapper Item (the layout child), not the Loader itself:
        // its `visible` collapses the cell, while the Loader inside stays
        // visible so it never overwrites the loaded item's own `visible`.
        Item {
            id: slot

            required property var modelData
            required property int index

            readonly property bool isSeparator: modelData.id === BarLayout.SEPARATOR_ID
            // Non-separator slots expose their widget's `shown`; separators
            // report none (their rendering is decided by sepShown).
            readonly property bool contentShown: !isSeparator && root.widgetShown(loader.item)

            visible: isSeparator ? (root.sepShown[slot.index] === true) : slot.contentShown
            implicitWidth: loader.implicitWidth
            implicitHeight: loader.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: modelData.id === root.capId && root.capFraction > 0 ? root.barWidth * root.capFraction : -1

            Loader {
                id: loader
                anchors.fill: parent
                // Never bind this Loader's `visible` (see the file comment).
                sourceComponent: root.resolve ? root.resolve(slot.modelData.id) : null
                onLoaded: {
                    if (!slot.isSeparator && root.configure)
                        root.configure(item, slot.modelData);
                }
            }
        }
    }
}
