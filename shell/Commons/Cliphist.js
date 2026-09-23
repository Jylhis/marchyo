// cliphist integration helpers, pure enough for Node tests.
//
// `cliphist list` emits "<id>\t<payload>" where the payload is the stored
// content quoted-printable-encoded ("=XX" hex escapes, one byte at a time).
// Binary payloads (images) start with "[[ binary data ". Decoding here in
// JS avoids one `cliphist decode` subprocess per visible row.
//
// Dual citizenship like Format.js: pure functions only, no Qt types, no
// I/O; tests/shell/launcher-test.js loads this from Node. No `.pragma`.

// QP payload -> JS string. Bytes decode as UTF-8 (including 4-byte
// sequences -> surrogate pairs); raw non-escaped chars pass through.
function decodePayload(payload) {
    var s = String(payload == null ? "" : payload);
    var bytes = [];
    for (var i = 0; i < s.length; i++) {
        if (s.charAt(i) === "=" && /^[0-9A-F]{2}$/.test(s.substr(i + 1, 2))) {
            bytes.push(parseInt(s.substr(i + 1, 2), 16));
            i += 2;
        } else {
            bytes.push(s.charCodeAt(i) & 0xff);
        }
    }
    var out = "";
    var c = 0;
    while (c < bytes.length) {
        var b = bytes[c];
        if (b < 0x80) {
            out += String.fromCharCode(b);
            c += 1;
        } else if (b >= 0xc0 && b < 0xe0 && c + 1 < bytes.length) {
            out += String.fromCharCode(((b & 0x1f) << 6) | (bytes[c + 1] & 0x3f));
            c += 2;
        } else if (b >= 0xe0 && b < 0xf0 && c + 2 < bytes.length) {
            out += String.fromCharCode(((b & 0x0f) << 12) | ((bytes[c + 1] & 0x3f) << 6) | (bytes[c + 2] & 0x3f));
            c += 3;
        } else if (b >= 0xf0 && c + 3 < bytes.length) {
            var cp = ((b & 0x07) << 18) | ((bytes[c + 1] & 0x3f) << 12) | ((bytes[c + 2] & 0x3f) << 6) | (bytes[c + 3] & 0x3f);
            cp -= 0x10000;
            out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
            c += 4;
        } else {
            out += String.fromCharCode(b); // lone continuation byte: pass through
            c += 1;
        }
    }
    return out;
}

// One `cliphist list` line -> { raw, text } (raw is the line to keep for
// future cliphist operations), or null for binary/unparseable rows.
function parseLine(line) {
    var s = String(line == null ? "" : line);
    var tab = s.indexOf("\t");
    if (tab < 0)
        return null;
    var payload = s.slice(tab + 1);
    if (payload.indexOf("[[ binary data ") === 0)
        return null;
    var text = decodePayload(payload);
    // Multi-line stores show their first line only.
    var nl = text.indexOf("\n");
    if (nl >= 0)
        text = text.slice(0, nl);
    return { raw: s, text: text };
}

if (typeof module !== "undefined")
    module.exports = {
        decodePayload: decodePayload,
        parseLine: parseLine
    };
