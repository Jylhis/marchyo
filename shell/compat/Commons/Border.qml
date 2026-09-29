pragma Singleton
import QtQuick

// omarchy-compat `Border` singleton. omarchy supports per-side widths and
// gradient borders via a spec object + a BorderOverlay; the shim only needs
// uniform, native (Rectangle.border-drawable) borders, so every spec is a flat
// `{ color, width }` and `needsOverlay` is always false (BorderSurface then
// draws with Rectangle.border and never activates the overlay).
QtObject {
    function none() {
        return {
            "color": "transparent",
            "width": 0
        };
    }
    function flat(color, width) {
        return {
            "color": color,
            "width": width
        };
    }
    // section/token select a themed border in omarchy; the shim ignores them
    // and uses the caller-supplied fallback colour + width.
    function surfaceSpec(section, token, fallbackColor, width) {
        return {
            "color": fallbackColor,
            "width": width
        };
    }

    function top(spec) {
        return spec ? (spec.width || 0) : 0;
    }
    function right(spec) {
        return spec ? (spec.width || 0) : 0;
    }
    function bottom(spec) {
        return spec ? (spec.width || 0) : 0;
    }
    function left(spec) {
        return spec ? (spec.width || 0) : 0;
    }
    function color(spec) {
        return spec ? (spec.color || "transparent") : "transparent";
    }
    function uniformWidth(spec) {
        return spec ? (spec.width || 0) : 0;
    }
    function canUseNative(spec) {
        return true;
    }
    function needsOverlay(spec) {
        return false;
    }
}
