import QtQuick
import QtQuick.Shapes

// One filled background segment of the segmented bar style, drawn behind a
// cluster of bar widgets by Ui/BarSection. Pure decoration: no input, no
// state, no effect on layout.
//
// Geometry is in the coordinates of the parent section (the Shape spans the
// whole section; nothing clips it). The segment covers [left, right] across
// the full section height:
//   - an outer end (no neighbour) is a rounded corner pair of `cornerRadius`;
//   - a join with a neighbour is a circular arc whose chord stands `joinDepth`
//     / 2 before the boundary and whose apex reaches `joinDepth` / 2 past it.
//     The earlier segment draws the arc convex (its right edge) and the later
//     one concave (its left edge) with the same chord and radius, so the two
//     meet without overlap or gap.
Shape {
    id: root

    // Section-space extent of the segment (boundary to boundary).
    property real segLeft: 0
    property real segRight: 0
    // Whether each end meets a neighbouring segment (true) or is an outer end.
    property bool joinLeft: false
    property bool joinRight: false
    // Horizontal depth of each join arc, centred on the boundary.
    property real joinDepthLeft: 0
    property real joinDepthRight: 0
    // Radius of the rounded outer ends (0 draws square ends).
    property real cornerRadius: 0
    property color fillColor: "transparent"

    // Arc radius for a join of depth d over the segment height: the circle
    // through both chord ends and the apex (sagitta d over a chord of h).
    function joinRadius(d: real): real {
        const h = root.height;
        return (h * h / 4 + d * d) / (2 * d);
    }

    // SVG path of the outline, traced clockwise from the top-left. SVG sweep
    // flag 1 is clockwise on screen (y grows downward).
    function outline(): string {
        const h = root.height;
        const r = Math.max(0, Math.min(root.cornerRadius, h / 2, (root.segRight - root.segLeft) / 2));
        const dl = Math.max(1, root.joinDepthLeft);
        const dr = Math.max(1, root.joinDepthRight);
        const l = root.segLeft;
        const rt = root.segRight;
        const arc = (rad, sweep, x, y) => " A " + rad + " " + rad + " 0 0 " + sweep + " " + x + " " + y;
        let p = root.joinLeft ? "M " + (l - dl / 2) + " 0" : "M " + (l + r) + " 0";
        if (root.joinRight) {
            p += " L " + (rt - dr / 2) + " 0";
            p += arc(root.joinRadius(dr), 1, rt - dr / 2, h);
        } else {
            p += " L " + (rt - r) + " 0";
            if (r > 0)
                p += arc(r, 1, rt, r);
            p += " L " + rt + " " + (h - r);
            if (r > 0)
                p += arc(r, 1, rt - r, h);
        }
        if (root.joinLeft) {
            p += " L " + (l - dl / 2) + " " + h;
            p += arc(root.joinRadius(dl), 0, l - dl / 2, 0);
        } else {
            p += " L " + (l + r) + " " + h;
            if (r > 0)
                p += arc(r, 1, l, h - r);
            p += " L " + l + " " + r;
            if (r > 0)
                p += arc(r, 1, l + r, 0);
        }
        return p + " Z";
    }

    // The curve renderer antialiases on the GPU without multisampling; under
    // the software backend Shape falls back to its QPainter renderer, which
    // honours `antialiasing`.
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
        fillColor: root.fillColor
        strokeWidth: -1
        strokeColor: "transparent"

        PathSvg {
            path: root.outline()
        }
    }
}
