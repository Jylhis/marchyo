function isCapture(node) {
    if (!node || !node.properties || !node.audio || node.audio.muted)
        return false;
    return node.properties["application.name"] !== "Quickshell Peak Detect"
        && node.name !== "quickshell" && node.name !== "quickshell-peak-monitor";
}

function steppedVolume(volume, delta) {
    return Math.max(0, Math.min(1, volume + (delta > 0 ? 0.05 : delta < 0 ? -0.05 : 0)));
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { isCapture, steppedVolume };
