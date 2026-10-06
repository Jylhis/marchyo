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
// The segmented bar style (ShellConfig.barStyleFor, "segmented") fills each
// cluster, the run of visible widgets between two rendered separators, with a
// Ui/BarSegment background. The tones alternate between Color.bgSubtle and
// an accent-tinted Color.surface, and adjacent segments meet in a curved join centred on the
// separator, whose rule is then transparent. The segments are drawn from the
// slots' own geometry by a zero-width layer behind them, so widths,
// positions, and paddings are identical in both styles. The flat style (the
// default) creates no layer at all.
//
// Visibility is read through the untyped helper below (not `slot.widget.shown`
// inline): qmllint types Repeater delegates as QQuickItem and Loader.item as
// QObject, so direct member access trips missing-property, while the runtime
// objects always have those members. Same indirection applyWidget() uses.
RowLayout {
    id: root

    // Section name into the layout ("left" | "center" | "right").
    property string section: ""
    // Output this section's bar sits on: entries come from
    // ShellConfig.barFor(screenName), so a `monitors.<name>` override applies.
    // Empty reads the global layout.
    property string screenName: ""
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

    // "flat" | "segmented", from this output's resolved `bar.style`. The
    // offscreen harness assigns it directly to bind both styles.
    property string barStyle: ShellConfig.barStyleFor(root.screenName)
    readonly property bool segmented: root.barStyle === "segmented"
    // Segmented-style colours, all derived from live Color tokens so a theme
    // swap recolours them: the two alternating segment tones (the odd one is
    // the surface tinted with the accent, so the pair stays distinguishable
    // in both variants) and the hover highlight Ui/BarItem uses on this
    // section, a stronger accent tint distinct from both tones.
    readonly property color segmentToneEven: Color.bgSubtle
    readonly property color segmentToneOdd: Qt.tint(Color.surface, Qt.alpha(Color.accent, 0.18))
    readonly property color segmentHover: Qt.tint(Color.surface, Qt.alpha(Color.accent, 0.36))

    readonly property var entries: root.entriesOverride || ShellConfig.barFor(root.screenName)[root.section] || []

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

    // A slot's horizontal widget padding (BarItem.padH), behind an untyped
    // parameter for the same qmllint reason. A widget without `padH` (a compat
    // plugin) reads as compact padding, the smallest a first-party item uses.
    function cellPad(cell): real {
        const w = cell ? cell.widget : null;
        if (w && typeof w.padH === "number")
            return w.padH;
        return Math.ceil(Style.barItemPad / 2);
    }

    // Segmented style: one { left, right, joinLeft, joinRight, depthLeft,
    // depthRight } per cluster, in section coordinates. A rendered separator
    // closes one segment and opens the next at its centre; the join depth spans
    // the separator plus the smaller padding of the two widgets flanking it, so
    // the curve stays inside the padding on both sides. Reading each slot's
    // x/width/visibility keeps the binding live across collapses and resizes.
    readonly property var segments: {
        if (!root.segmented)
            return [];
        const out = [];
        let cur = null;
        let pendingJoin = null;
        let lastPad = 0;
        for (let k = 0; k < repeater.count; k++) {
            const cell = repeater.itemAt(k);
            if (!cell)
                continue;
            if (root.entries[k] && root.entries[k].id === BarLayout.SEPARATOR_ID) {
                if (root.sepShown[k] !== true || !cur)
                    continue;
                const centre = cell.x + cell.width / 2;
                cur.right = centre;
                cur.joinRight = true;
                cur.sepWidth = cell.width;
                cur.padRight = lastPad;
                out.push(cur);
                pendingJoin = centre;
                cur = null;
                continue;
            }
            if (!root.cellShown(cell))
                continue;
            const pad = root.cellPad(cell);
            if (!cur) {
                const joined = pendingJoin !== null;
                cur = {
                    left: joined ? pendingJoin : cell.x,
                    right: cell.x + cell.width,
                    joinLeft: joined,
                    joinRight: false,
                    padLeft: pad,
                    padRight: pad,
                    sepWidth: 0
                };
                pendingJoin = null;
            } else {
                cur.right = cell.x + cell.width;
            }
            lastPad = pad;
        }
        if (cur)
            out.push(cur);
        else if (pendingJoin !== null && out.length > 0)
            out[out.length - 1].joinRight = false; // no successor (BarLayout never renders one)
        for (let i = 0; i < out.length; i++) {
            const s = out[i];
            const next = out[i + 1];
            s.depthRight = s.joinRight && next ? 2 * Math.min(s.padRight, next.padLeft) + s.sepWidth : 0;
            s.depthLeft = i > 0 ? out[i - 1].depthRight : 0;
        }
        return out;
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

    // Segmented-style background layer: a zero-width layout item at x = 0
    // (row spacing is 0, so it shifts nothing), stacked behind the slots, with
    // segments that paint outside its own bounds in section coordinates. Not
    // created, and skipped by the layout, in the flat style.
    Loader {
        id: segmentLayer
        visible: root.segmented
        active: root.segmented
        z: -1
        Layout.preferredWidth: 0
        Layout.maximumWidth: 0
        Layout.fillHeight: true

        sourceComponent: Item {
            Repeater {
                model: root.segments

                BarSegment {
                    required property var modelData
                    required property int index

                    x: -segmentLayer.x
                    width: root.width
                    height: root.height
                    segLeft: modelData.left
                    segRight: modelData.right
                    joinLeft: modelData.joinLeft
                    joinRight: modelData.joinRight
                    joinDepthLeft: modelData.depthLeft
                    joinDepthRight: modelData.depthRight
                    cornerRadius: Style.barRadius
                    fillColor: Qt.alpha(index % 2 === 0 ? root.segmentToneEven : root.segmentToneOdd, Style.surfaceAlpha)
                }
            }
        }
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
            // The loaded widget, for root.cellPad().
            readonly property var widget: loader.item

            visible: isSeparator ? (root.sepShown[slot.index] === true) : slot.contentShown
            implicitWidth: loader.implicitWidth
            implicitHeight: loader.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: modelData.id === root.capId && root.capFraction > 0 ? root.barWidth * root.capFraction : -1

            Loader {
                id: loader
                anchors.fill: parent
                // The segmented style draws its own curved join in place of
                // the separator rule; the slot keeps its width.
                opacity: slot.isSeparator && root.segmented ? 0 : 1
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
