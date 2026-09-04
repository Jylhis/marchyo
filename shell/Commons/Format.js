// Pure parsing/formatting helpers shared by the Services singletons.
//
// Why a .js module and not inline QML functions: QML logic can only be
// exercised by starting a shell, and `just -f shell/Justfile check` needs a Qt
// platform plugin, so none of it is reachable from `nix flake check`. A plain
// JavaScript module has dual citizenship — QML imports it directly and ignores
// the CommonJS guard at the bottom, while Node loads it as an ordinary module —
// so every branch below is unit-tested headlessly by
// tests/shell/format-test.js, which `nix flake check` runs. Anything in here
// must therefore stay pure: no Qt types, no globals, no I/O.
//
// Deliberately NOT a `.pragma library` module: that directive is the natural
// QML idiom for a stateless helper, but it is a syntax error to Node, which
// would cost the headless tests. Everything here is stateless anyway, so the
// only thing the pragma would buy is one shared copy instead of one per
// importing QML document.

// Common full keymap names -> the short codes waybar's "{short}" renders.
var SHORT_CODES = {
    "English (US)": "us",
    "English (UK)": "gb",
    "Finnish": "fi",
    "Swedish": "se",
    "German": "de",
    "French": "fr",
    "Norwegian": "no"
};

// Hyprland's active_keymap ("English (US)") -> a short bar label ("us").
// Unknown names fall back to the first word, lowercased and clipped to three
// characters, which is a readable code for most layouts and never a stray
// full-width label in the bar.
function shortCode(keymap) {
    if (!keymap)
        return "";
    if (Object.prototype.hasOwnProperty.call(SHORT_CODES, keymap))
        return SHORT_CODES[keymap];
    return keymap.split(/[ (]/)[0].toLowerCase().slice(0, 3);
}

// `nmcli -t -f active,ssid,signal dev wifi` -> { ssid, signal } for the active
// network, or nulls when nothing is active.
//
// `-t` escapes a colon inside a field as "\:", so a naive split on ":" tears an
// SSID like "Cafe: Free" into pieces and reads its second half as the signal.
// splitTerse below unescapes properly; signal is only accepted when it is
// actually numeric, so a torn line degrades to "no reading" instead of 0%.
function parseWifi(text) {
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = splitTerse(lines[i]);
        if (parts[0] !== "yes")
            continue;
        var signal = parseInt(parts[2], 10);
        return {
            ssid: parts[1] || "",
            signal: isNaN(signal) ? -1 : signal
        };
    }
    return {
        ssid: "",
        signal: -1
    };
}

// `nmcli -t -f DEVICE,STATE,IP4.ADDRESS device status` -> { ifName, ipAddress }
// for the first connected device that actually has an address. Disconnected
// devices leave the address field empty.
function parseDeviceStatus(text) {
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = splitTerse(lines[i]);
        if (parts.length < 3 || parts[1] !== "connected" || !parts[2])
            continue;
        return {
            ifName: parts[0],
            // "192.168.1.10/24" -> "192.168.1.10".
            ipAddress: parts[2].split("/")[0]
        };
    }
    return {
        ifName: "",
        ipAddress: ""
    };
}

// Split one `nmcli -t` record into its fields. nmcli escapes a literal colon or
// backslash inside a value with a backslash; splitting on a bare ":" would cut
// such a value in half.
function splitTerse(line) {
    var fields = [];
    var current = "";
    var text = String(line || "");
    for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i);
        if (ch === "\\" && i + 1 < text.length) {
            current += text.charAt(++i);
        } else if (ch === ":") {
            fields.push(current);
            current = "";
        } else {
            current += ch;
        }
    }
    fields.push(current);
    return fields;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        shortCode: shortCode,
        parseWifi: parseWifi,
        parseDeviceStatus: parseDeviceStatus,
        splitTerse: splitTerse
    };
