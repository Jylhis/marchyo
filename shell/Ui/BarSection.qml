import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../Commons/BarLayout.js" as BarLayout

// One anchored section of the bar (left / center / right): a row of widget
// slots driven by the ShellConfig layout entries for `section`.
//
// Slots collapse with their widget. Every conditional widget hides itself with
// `visible: false` (media with no player, idle mic, desktop battery, ...), but
// a Loader whose item is hidden still occupies its cell: the layout sizes the
// cell from the Loader, and the Loader — not its item — is the layout child
// that is visible. Hiding the Loader as well makes the layout skip the cell
// entirely, spacing included, exactly as it skips a directly hidden child.
// Without this the bar shows a dead gap the width of every hidden widget.
//
// The collapse binding is attached in onLoaded, NEVER declared on the Loader:
// QQuickLoader imperatively writes item.visible from its own visibility as
// the item is created, overwriting the item's own binding. A Loader that is
// already hidden at the load instant poisons every loaded widget invisible,
// permanently (even item.visible = true reads back false — verified against
// Qt 6.11 offscreen), which is how a declarative `visible: itemShown(item)`
// binding here once rendered the whole bar empty. Attaching the binding only
// after the item exists leaves the item's own visible logic intact.
//
// Separators are cluster-aware: a rule renders only between two clusters that
// both have visible content, and the rules around an empty cluster collapse
// to one. The decision table is Commons/BarLayout.js (pure, node-tested via
// tests/shell/bar-layout-test.js); this component only feeds it the entry ids
// plus each loaded widget's visibility. A stray rule next to a collapsed
// cluster reads as a floating pixel, and before this component existed every
// separator rendered unconditionally.
//
// Visibility is read through the untyped helpers below (not `slot.item.visible`
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

    spacing: Style.spacing

    readonly property var entries: root.entriesOverride || ShellConfig.bar[root.section] || []

    // A slot's widget visibility, ignoring separator slots (their rendering is
    // decided by sepShown, not by their own visible flag).
    function slotShown(slot, id): bool {
        if (!slot || id === BarLayout.SEPARATOR_ID)
            return false;
        const w = slot.item;
        return w ? w.visible === true : false;
    }

    // The loaded item's visibility, for the Loader's collapse binding.
    function itemShown(w): bool {
        return w ? w.visible === true : false;
    }

    // Attach a slot's collapse binding AFTER its item exists (see the file
    // comment for why the Loader's own visible must not be bound earlier):
    // Loader visible exactly while its widget is. Runs through an untyped
    // parameter for the same qmllint reason as slotShown.
    function bindCollapse(loader): void {
        if (loader)
            loader.visible = Qt.binding(() => root.itemShown(loader.item));
    }

    // Point a freshly loaded separator at its sepShown cell. Called from
    // onLoaded (where `item` is QObject-typed), so the member write lives
    // behind an untyped parameter for the same qmllint reason as above.
    function bindSeparator(loader, index): void {
        if (loader)
            loader.visible = Qt.binding(() => root.sepShown[index]);
    }

    // Per-entry separator render decision (true = draw the rule). Reading
    // repeater.count and each slot's item visibility here is what keeps the
    // binding live: any widget flipping visible re-runs the computation, and
    // so does a layout change (ShellConfig re-read) through root.entries.
    readonly property var sepShown: {
        const ids = [];
        for (let k = 0; k < root.entries.length; k++)
            ids.push(root.entries[k].id);
        const shown = [];
        for (let k = 0; k < repeater.count; k++)
            shown.push(root.slotShown(repeater.itemAt(k), ids[k]));
        return BarLayout.separatorVisibility(ids, shown);
    }

    Repeater {
        id: repeater
        model: root.entries

        Loader {
            id: slot

            required property var modelData
            required property int index

            // No visible binding here; bindCollapse() attaches it on load.
            sourceComponent: root.resolve ? root.resolve(modelData.id) : null
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: modelData.id === root.capId && root.capFraction > 0 ? root.barWidth * root.capFraction : -1

            onLoaded: {
                if (modelData.id === BarLayout.SEPARATOR_ID) {
                    root.bindSeparator(slot, slot.index);
                } else {
                    if (root.configure)
                        root.configure(item, modelData);
                    root.bindCollapse(slot);
                }
            }
        }
    }
}
