function minutes(text) {
    var value = String(text).trim();
    if (!/^[0-9]+$/.test(value))
        return 0;
    var n = Number(value);
    return Number.isSafeInteger(n) && n > 0 ? n : 0;
}

function scheduleArgs(cli, count, message, fallback) {
    return [cli, "reminder", "set", "--", String(message).trim() || fallback, String(count) + "m"];
}

if (typeof module !== "undefined")
    module.exports = { minutes: minutes, scheduleArgs: scheduleArgs };
