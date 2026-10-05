// cliphist integration helpers, pure enough for Node tests.
//
// `cliphist list` emits "<id>\t<payload>" where the payload is the stored
// content quoted-printable-encoded ("=XX" hex escapes, one byte at a time).
// Binary payloads (images) start with "[[ binary data " and carry a preview
// of size, format and dimensions instead of content. Decoding text here in
// JS avoids one `cliphist decode` subprocess per visible row; only image
// thumbnails need `cliphist decode`.
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

// Image formats cliphist's preview names (Go image.DecodeConfig) that Qt's
// image plugins also load. Anything else stays a skipped binary row.
var IMAGE_FORMATS = ["png", "jpeg", "gif", "bmp", "webp"];

var SIZE_UNITS = { "B": 1, "KiB": 1024, "MiB": 1024 * 1024, "GiB": 1024 * 1024 * 1024 };

// A binary payload ("[[ binary data 12 KiB png 800x600 ]]") -> { bytes,
// sizeText, format, width, height } for a loadable image, else null
// (text, non-image binaries such as "[[ binary data 3 KiB application/pdf ]]",
// and anything that does not match the format exactly).
function parseImage(payload) {
    var m = /^\[\[ binary data (\d+(?:\.\d+)?) (B|KiB|MiB|GiB) ([a-z0-9]+) (\d+)x(\d+) \]\]$/.exec(String(payload == null ? "" : payload));
    if (!m || IMAGE_FORMATS.indexOf(m[3]) < 0)
        return null;
    return {
        bytes: Math.round(parseFloat(m[1]) * SIZE_UNITS[m[2]]),
        sizeText: m[1] + " " + m[2],
        format: m[3],
        width: parseInt(m[4], 10),
        height: parseInt(m[5], 10)
    };
}

// Cache file name for an image entry: keyed by id, with the dimensions and
// size folded in so an id reused after `cliphist wipe` misses the stale file.
// Only digits, "x", "-" and the [a-z0-9] format reach the name.
function cacheName(id, image) {
    return id + "-" + image.width + "x" + image.height + "-" + image.bytes + "." + image.format;
}

// Searchable row title for an image entry, e.g. "png 800x600 · 12 KiB".
function describeImage(image) {
    return image.format + " " + image.width + "x" + image.height + " \u00b7 " + image.sizeText;
}

// One `cliphist list` line -> { raw, id, text, image } (raw is the line to
// keep for future cliphist operations). Text rows carry `image: null`; image
// rows carry the parseImage() record, `text: ""` and a numeric `id` (the only
// form that is ever passed to `cliphist decode`). Other binary and
// unparsable rows are null.
function parseLine(line) {
    var s = String(line == null ? "" : line);
    var tab = s.indexOf("\t");
    if (tab < 0)
        return null;
    var id = s.slice(0, tab);
    var payload = s.slice(tab + 1);
    if (payload.indexOf("[[ binary data ") === 0) {
        var image = parseImage(payload);
        if (!image || !/^[0-9]+$/.test(id))
            return null;
        return { raw: s, id: id, text: "", image: image };
    }
    var text = decodePayload(payload);
    // Multi-line stores show their first line only.
    var nl = text.indexOf("\n");
    if (nl >= 0)
        text = text.slice(0, nl);
    return { raw: s, id: id, text: text, image: null };
}

if (typeof module !== "undefined")
    module.exports = {
        decodePayload: decodePayload,
        parseImage: parseImage,
        cacheName: cacheName,
        describeImage: describeImage,
        parseLine: parseLine
    };
