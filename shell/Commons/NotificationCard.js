function pauseExpiry(entry, paused, now) {
    if (paused && entry.deadline > 0) {
        entry.remaining = Math.max(1, entry.deadline - now);
        entry.deadline = 0;
    } else if (!paused && entry.remaining > 0) {
        entry.deadline = now + entry.remaining;
        entry.remaining = 0;
    }
}

function age(ts, now) {
    const then = new Date(ts);
    const today = new Date(now);
    const days = Math.round((Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
        - Date.UTC(then.getFullYear(), then.getMonth(), then.getDate())) / 86400000);
    if (days === 1)
        return {kind: "yesterday"};
    if (days > 1)
        return {kind: "date"};
    const minutes = Math.max(0, Math.floor((now - ts) / 60000));
    return minutes < 60 ? {kind: "minutes", value: minutes} : {kind: "time"};
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {pauseExpiry: pauseExpiry, age: age};
