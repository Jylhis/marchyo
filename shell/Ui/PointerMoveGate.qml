import QtQuick
import qs.Commons

// Ignores hover that content movement causes under a still pointer. Place it
// over a surface (it fills its parent and never takes input): real pointer
// motion sets Pointer.moved, and hold() clears it, so keyboard navigation and
// scrolling can claim the selection until the pointer moves again.
Item {
    id: root

    anchors.fill: parent

    // Pointer travel, in pixels, that counts as a real move.
    property real threshold: 2
    property real lastX: -1
    property real lastY: -1

    function hold(): void {
        Pointer.moved = false;
    }

    function release(): void {
        Pointer.moved = true;
    }

    HoverHandler {
        id: hover
        onPointChanged: {
            const p = hover.point.position;
            if (root.lastX < 0) {
                root.lastX = p.x;
                root.lastY = p.y;
                return;
            }
            if (Math.abs(p.x - root.lastX) + Math.abs(p.y - root.lastY) >= root.threshold) {
                root.lastX = p.x;
                root.lastY = p.y;
                Pointer.moved = true;
            }
        }
        onHoveredChanged: {
            if (!hover.hovered)
                root.lastX = -1;
        }
    }
}
