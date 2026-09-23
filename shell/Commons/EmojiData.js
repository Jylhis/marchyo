// Emoji catalog for the launcher's emoji mode.
//
// RAW holds "<group>|<subgroup>|<chars>|<name>" rows. The list below is a
// small dev subset so `quickshell -p shell` runs standalone; the Nix build
// (packages/marchyo-shell/package.nix) REGENERATES the rows between the two
// generated markers in the array from pkgs.unicode-emoji's emoji-test.txt
// (fully-qualified entries, Component group dropped). Dual citizenship like
// Format.js: pure data + pure parse, no Qt types, Node-testable; no
// `.pragma` line (Node cannot parse one).
//
// Emoji names never contain "|" (Unicode data names use spaces and dashes),
// so a plain split is the whole parser. The markers sit INSIDE the array
// brackets on their own comment lines: the Nix build splices between them,
// so nothing outside this file's own markers may spell them (the splice
// greps for the marker text).
var RAW = [
    // BEGIN-GENERATED (dev subset — the Nix build replaces the rows below)
    "Smileys & Emotion|face-smiling|🙂|slightly smiling face",
    "Smileys & Emotion|face-smiling|😀|grinning face",
    "Smileys & Emotion|face-smiling|😃|grinning face with big eyes",
    "Smileys & Emotion|face-smiling|😄|grinning face with smiling eyes",
    "Smileys & Emotion|face-smiling|😆|grinning squinting face",
    "Smileys & Emotion|face-smiling|😉|winking face",
    "Smileys & Emotion|face-affection|😍|smiling face with heart-eyes",
    "Smileys & Emotion|face-affection|😘|face blowing a kiss",
    "Smileys & Emotion|face-glasses|😎|smiling face with sunglasses",
    "Animals & Nature|animal-mammal|🐶|dog face",
    "Animals & Nature|animal-mammal|🐱|cat face",
    "Food & Drink|food-fruit|🍎|red apple",
    "Food & Drink|food-drink|☕|hot beverage"
    // END-GENERATED
];

// RAW rows -> [{ group, subgroup, chars, name }], preserving file order.
function parse(raw) {
    var out = [];
    for (var i = 0; i < raw.length; i++) {
        var f = String(raw[i]).split("|");
        if (f.length !== 4)
            continue; // a malformed row degrades to skipped, never crashes the view
        out.push({ group: f[0], subgroup: f[1], chars: f[2], name: f[3] });
    }
    return out;
}

if (typeof module !== "undefined")
    module.exports = {
        RAW: RAW,
        parse: parse
    };
