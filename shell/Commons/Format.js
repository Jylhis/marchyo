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

// `nmcli -t -f GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS device show` -> one
// record per device, in nmcli's order.
//
// Why `device show` and not `device status`: IP4.ADDRESS is not a valid
// `device status` field. That command exits 2 with "invalid field
// 'IP4.ADDRESS'" and prints nothing, so the address was never resolvable.
//
// `device show` emits one blank-line-separated block of "key:value" lines per
// device. Three shapes have to be tolerated:
//   - GENERAL.STATE carries the numeric code first: "100 (connected)", not a
//     bare "connected".
//   - the address key is indexed: "IP4.ADDRESS[1]".
//   - a device with no address omits the IP4.ADDRESS line entirely rather than
//     emitting an empty one.
function parseDeviceShow(text) {
    var lines = String(text || "").split("\n");
    var records = [];
    var current = null;
    for (var i = 0; i < lines.length; i++) {
        var parts = splitTerse(lines[i]);
        var key = parts[0];
        var value = parts.length > 1 ? parts[1] : "";
        if (key === "GENERAL.DEVICE") {
            current = {
                ifName: value,
                state: "",
                // "192.168.1.10/24" -> "192.168.1.10".
                ipAddress: ""
            };
            records.push(current);
        } else if (!current) {
            continue;
        } else if (key === "GENERAL.STATE") {
            current.state = value;
        } else if (key.indexOf("IP4.ADDRESS") === 0 && !current.ipAddress) {
            current.ipAddress = value.split("/")[0];
        }
    }
    return records;
}

// The device whose address the bar and tooltip should show: the first
// NetworkManager-connected device that actually has an IPv4 address.
//
// Loopback is skipped by name, and a device NetworkManager only tracks
// ("connected (externally)" — container and VPN bridges, or any interface owned
// by systemd-networkd) is used only as a fallback, so a podman bridge never
// masks the real uplink on a normally-managed host.
function parseDeviceAddress(text) {
    var records = parseDeviceShow(text);
    var fallback = null;
    for (var i = 0; i < records.length; i++) {
        var rec = records[i];
        if (rec.ifName === "lo" || !rec.ipAddress || !/^100\b/.test(rec.state))
            continue;
        if (rec.state.indexOf("externally") === -1)
            return {
                ifName: rec.ifName,
                ipAddress: rec.ipAddress
            };
        if (!fallback)
            fallback = {
                ifName: rec.ifName,
                ipAddress: rec.ipAddress
            };
    }
    return fallback || {
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
        parseDeviceShow: parseDeviceShow,
        parseDeviceAddress: parseDeviceAddress,
        splitTerse: splitTerse
    };
