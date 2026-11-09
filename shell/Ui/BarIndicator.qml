import QtQuick

BarItem {
    id: root

    property bool indicatorActive: false
    property bool indicatorAvailable: true
    function groupRevealed(start): bool {
        for (let p = start; p; p = p.parent) {
            if (p.indicatorsRevealed !== undefined)
                return p.indicatorsRevealed;
        }
        return false;
    }
    readonly property bool revealed: root.groupRevealed(root.parent)

    compact: true
    shown: root.indicatorAvailable && (root.indicatorActive || root.revealed)
    opacity: !root.shown ? 0 : root.indicatorActive ? 1 : 0.45
    visible: root.shown || opacity > 0
}
