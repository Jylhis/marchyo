pragma Singleton
import QtQuick
import qs.Commons as M
import "BorderGeometry.js" as Geometry

// omarchy-compat `Border` singleton: the spec shape of omacom/omarchy@quattro's
// Commons/Border ({ color, widths, gradient }, so the vendored BorderOverlay
// and BorderGeometry work unchanged), without its shell.toml reader. Themed
// surface and control borders resolve to marchyo's Jylhis tokens (Colors and
// Style.controls); the caller's fallback colour and width are used for
// surfaces. Gradients are never produced, and every width is uniform, so
// surfaces draw with a native Rectangle.border.
QtObject {
    id: root

    function none() {
        return flat("transparent", 0);
    }

    function flat(color, width) {
        return {
            "color": color || "transparent",
            "widths": Geometry.parseWidthSpec(width, 0),
            "gradient": {
                "colors": [],
                "angle": 0,
                "enabled": false
            }
        };
    }

    // section/token/alphaKey select a themed border in omarchy; marchyo has no
    // per-surface border keys, so the caller's colour and width apply.
    function surfaceSpec(section, token, fallbackColor, fallbackWidth, alphaKey) {
        return flat(fallbackColor, fallbackWidth);
    }

    function localOrSurfaceSpec(section, token, localColor, defaultColor, fallbackWidth, alphaKey) {
        return flat(localColor, fallbackWidth);
    }

    function controlState(state) {
        if (state === "hover-cursor" || state === "hot")
            return "hover";
        return state || "normal";
    }

    function controlHasWidth(state) {
        return M.Style.control(controlState(state)).borderWidth > 0;
    }

    function controlSpec(state, foreground, accent, urgent) {
        const c = M.Style.control(controlState(state));
        return flat(c.border, c.borderWidth);
    }

    function withWidth(spec, width) {
        if (!spec)
            return none();
        return {
            "color": spec.color,
            "gradient": spec.gradient,
            "widths": Geometry.parseWidthSpec(width, 0)
        };
    }

    function isNone(spec) {
        return !spec || Geometry.maxWidth(spec.widths) <= 0;
    }
    function needsOverlay(spec) {
        return Geometry.needsOverlay(spec);
    }
    function canUseNative(spec) {
        return Geometry.canUseNative(spec);
    }
    function top(spec) {
        return spec && spec.widths ? spec.widths.top : 0;
    }
    function right(spec) {
        return spec && spec.widths ? spec.widths.right : 0;
    }
    function bottom(spec) {
        return spec && spec.widths ? spec.widths.bottom : 0;
    }
    function left(spec) {
        return spec && spec.widths ? spec.widths.left : 0;
    }
    function uniformWidth(spec) {
        return spec && spec.widths ? spec.widths.top : 0;
    }
    function color(spec) {
        return spec ? spec.color : "transparent";
    }
}
