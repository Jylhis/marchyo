function deviceGlyph(node, input) {
    var props = node ? node.properties || {} : {};
    var text = [node ? node.name : "", node ? node.description : "",
        node ? node.nickname : "", props["device.icon-name"] || ""].join(" ");
    if (/headphone|headset|earbud|earphone|airpod/i.test(text))
        return "󰋋";
    return input ? "󰍬" : "󰓃";
}

function rawStreamLabel(node) {
    if (!node)
        return "";
    var props = node.properties || {};
    return props["application.name"] || node.description || node.nickname || node.name || "";
}

function represents(label, player) {
    var left = String(label || "").trim().toLowerCase();
    var right = String(player || "").trim().toLowerCase();
    return left && right && (left.indexOf(right) !== -1 || right.indexOf(left) !== -1);
}

function streamLabel(node, players, streams) {
    var raw = rawStreamLabel(node);
    var generic = raw.toLowerCase() === "audio-src";
    var candidates = (players || []).filter(function (p) {
        if (!p || (!p.isPlaying && !p.canPlay) || /playerctld/i.test(p.dbusName || ""))
            return false;
        var label = p.identity || p.desktopEntry || "";
        if (!label)
            return false;
        if (!generic)
            return represents(raw, label);
        return !(streams || []).some(function (s) {
            var text = rawStreamLabel(s);
            return text.toLowerCase() !== "audio-src" && represents(text, label);
        });
    });
    var playing = candidates.filter(function (p) { return p.isPlaying; });
    if (playing.length === 1)
        candidates = playing;
    return candidates.length === 1
        ? candidates[0].identity || candidates[0].desktopEntry : raw;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { deviceGlyph: deviceGlyph, streamLabel: streamLabel };
