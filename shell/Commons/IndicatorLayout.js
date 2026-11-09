var INDICATORS = ["marchyo.screenRecording", "marchyo.reminders", "marchyo.remoteSession",
    "marchyo.dictation", "marchyo.caffeine", "marchyo.dnd", "marchyo.nightLight",
    "marchyo.camera", "marchyo.mic"];

function groupEntries(entries) {
    const result = [];
    for (const entry of entries) {
        if (INDICATORS.indexOf(entry.id) < 0) {
            result.push(entry);
            continue;
        }
        let group = result[result.length - 1];
        if (!group || !group.indicators) {
            group = { id: "indicatorGroup", indicators: [] };
            result.push(group);
        }
        group.indicators.push(entry);
    }
    return result;
}

function activeOrder(previous, active) {
    const order = previous.filter(i => active[i]);
    for (let i = 0; i < active.length; i++) {
        if (active[i] && order.indexOf(i) < 0)
            order.push(i);
    }
    return order;
}

function positions(widths, active, fixedRight, previous) {
    const order = activeOrder(previous || [], active)
        .concat(widths.map((_, i) => i).filter(i => !active[i]));
    const total = widths.reduce((sum, width) => sum + width, 0);
    const offsets = new Array(widths.length);
    let edge = 0;
    for (const i of order) {
        offsets[i] = fixedRight ? total - edge - widths[i] : edge;
        edge += widths[i];
    }
    return { offsets, total };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { groupEntries, activeOrder, positions };
