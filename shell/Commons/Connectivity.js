// Pure NetworkManager connectivity helpers shared by Services/NetworkStatus.
//
// Same dual-citizenship arrangement as Format.js (see its header): QML imports
// this directly and ignores the CommonJS guard at the bottom, Node loads it as
// an ordinary module, so tests/shell/connectivity-test.js runs headless.

// Member names of Quickshell's NetworkConnectivity enum.
var NAMES = ["Unknown", "None", "Portal", "Limited", "Full"];

// Name of an enum value, given the enum object (`NetworkConnectivity` in QML).
// A value that matches no member, or a missing enum, is "Unknown".
function fromEnum(value, enumObject) {
    for (var i = 0; enumObject && i < NAMES.length; i++)
        if (enumObject[NAMES[i]] === value)
            return NAMES[i];
    return "Unknown";
}

// A restricted network answers but does not give full internet access.
function isRestricted(name) {
    return name === "Portal" || name === "Limited";
}

// Node (tests) picks this up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        NAMES: NAMES,
        fromEnum: fromEnum,
        isRestricted: isRestricted
    };
