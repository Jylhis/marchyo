// Pure string-layer logic shared by Commons/I18n.qml: catalog lookup with
// per-key English fallback, %N hole substitution, CLDR plural selection and
// number formatting. Catalogs are flat objects of dotted keys; a value is a
// string or a plural entry ({ "one": ..., "other": ... }).
//
// Same dual-citizenship arrangement as Format.js: QML imports this directly
// and ignores the CommonJS guard at the bottom. Keep it pure (no Qt types, no
// I/O). The CLI mirrors the lookup in packages/marchyo-cli/packages/core/src/i18n.ts.

function within(value, low, high) {
    return value >= low && value <= high;
}

// CLDR cardinal plural category of a whole count for a registry language code.
function category(code, count) {
    const n = Math.abs(Math.trunc(Number(count) || 0));
    const n10 = n % 10;
    const n100 = n % 100;
    const millions = n !== 0 && n % 1000000 === 0;

    switch (String(code || "")) {
    case "ja":
    case "ko":
    case "zh-CN":
    case "zh-TW":
    case "th":
    case "vi":
    case "id":
    case "ms":
        return "other";
    case "hi":
    case "bn":
    case "fa":
    case "si":
        return n <= 1 ? "one" : "other";
    case "fr":
    case "pt-BR":
        return n <= 1 ? "one" : millions ? "many" : "other";
    case "ca":
    case "es-MX":
    case "it":
    case "pt":
        return n === 1 ? "one" : millions ? "many" : "other";
    case "fil":
        return (n10 === 4 || n10 === 6 || n10 === 9) ? "other" : "one";
    case "is":
        return n10 === 1 && n100 !== 11 ? "one" : "other";
    case "cs":
    case "sk":
        return n === 1 ? "one" : within(n, 2, 4) ? "few" : "other";
    case "pl":
        if (n === 1)
            return "one";
        return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "many";
    case "ru":
    case "uk":
        if (n10 === 1 && n100 !== 11)
            return "one";
        return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "many";
    case "hr":
    case "sr":
        if (n10 === 1 && n100 !== 11)
            return "one";
        return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "other";
    case "sl":
        if (n100 === 1)
            return "one";
        if (n100 === 2)
            return "two";
        return within(n100, 3, 4) ? "few" : "other";
    case "lt":
        if (within(n100, 11, 19))
            return "other";
        return n10 === 1 ? "one" : n10 >= 2 ? "few" : "other";
    case "lv":
        if (n10 === 0 || within(n100, 11, 19))
            return "zero";
        return n10 === 1 ? "one" : "other";
    case "ro":
        if (n === 1)
            return "one";
        return n === 0 || within(n100, 1, 19) ? "few" : "other";
    case "ar":
        if (n <= 2)
            return ["zero", "one", "two"][n];
        return within(n100, 3, 10) ? "few" : within(n100, 11, 99) ? "many" : "other";
    case "he":
        return n === 1 ? "one" : n === 2 ? "two" : "other";
    case "ga":
        if (n <= 2)
            return n === 0 ? "other" : n === 1 ? "one" : "two";
        return within(n, 3, 6) ? "few" : within(n, 7, 10) ? "many" : "other";
    default:
        return n === 1 ? "one" : "other";
    }
}

// The string for a count from a catalog entry, or the entry itself when it is
// a plain string. A plural entry missing the category falls back to "other".
// Undefined when the entry gives nothing usable.
function pick(entry, code, count) {
    if (typeof entry === "string")
        return entry.length > 0 ? entry : undefined;
    if (!entry || typeof entry !== "object")
        return undefined;
    const form = entry[category(code, count)];
    if (typeof form === "string" && form.length > 0)
        return form;
    return typeof entry.other === "string" && entry.other.length > 0 ? entry.other : undefined;
}

// Replace %1, %2, ... with the matching argument. A hole without an argument
// is left as written.
function substitute(text, args) {
    const list = args || [];
    return String(text).replace(/%(\d+)/g, function (whole, index) {
        const i = Number(index) - 1;
        return i >= 0 && i < list.length ? String(list[i]) : whole;
    });
}

// The raw entry for a key: the language catalog first, then English.
function entry(language, english, key) {
    const own = language ? language[key] : undefined;
    if (pick(own, "en", 1) !== undefined)
        return {
            value: own,
            english: false
        };
    const fallback = english ? english[key] : undefined;
    if (pick(fallback, "en", 1) !== undefined)
        return {
            value: fallback,
            english: true
        };
    return null;
}

// Translate a key. A plural entry reads as its "other" form; use tn() for a
// count-dependent choice. The key itself answers when no catalog has it.
function t(language, english, key, args) {
    const found = entry(language, english, key);
    if (found === null)
        return key;
    return substitute(pick(found.value, "en", 2), args);
}

// Translate a key by count using the language's plural rules; English entries
// use English rules. The count is not substituted unless the caller passes it
// in args.
function tn(language, english, code, key, count, args) {
    const found = entry(language, english, key);
    if (found === null)
        return key;
    return substitute(pick(found.value, found.english ? "en" : code, count), args);
}

// A number in the language's decimal separator and digits, ungrouped:
// formatNumber(13.14, 1, ",", "0") is "13,1". Without decimals the value is
// written as it is.
function formatNumber(value, decimals, decimal, zeroDigit) {
    const number = Number(value);
    if (!isFinite(number))
        return String(value);
    let text = decimals === undefined || decimals === null ? String(number) : number.toFixed(decimals);
    if (decimal && decimal !== ".")
        text = text.replace(".", decimal);
    if (zeroDigit && zeroDigit !== "0") {
        const zero = zeroDigit.charCodeAt(0);
        text = text.replace(/[0-9]/g, function (digit) {
            return String.fromCharCode(zero + digit.charCodeAt(0) - 48);
        });
    }
    return text;
}

// Parse catalog text to a plain object; anything unusable is an empty catalog.
function parseCatalog(raw) {
    try {
        const parsed = JSON.parse(raw || "{}");
        return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (e) {
        return {};
    }
}

// The effective language code: the runtime override when the registry knows
// it, else the baked default when known, else English.
function resolveLanguage(override, baked, registry) {
    const known = registry || {};
    const candidates = [override, baked];
    for (let i = 0; i < candidates.length; i++) {
        const code = String(candidates[i] || "").trim();
        if (code !== "" && Object.prototype.hasOwnProperty.call(known, code))
            return code;
    }
    return "en";
}

// Node (tests) picks this up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        category: category,
        pick: pick,
        substitute: substitute,
        t: t,
        tn: tn,
        formatNumber: formatNumber,
        parseCatalog: parseCatalog,
        resolveLanguage: resolveLanguage
    };
