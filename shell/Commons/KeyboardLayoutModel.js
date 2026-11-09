function isTypedKeyboard(name) {
    const untyped = /^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)/;
    const hotkey = /(-wmi-hotkeys|-wireless-radio-control)(-\d+)?$/;
    return typeof name === "string" && name.length > 0
        && !untyped.test(name) && !hotkey.test(name);
}

function selectKeyboard(keyboards, eventName) {
    const typed = (Array.isArray(keyboards) ? keyboards : [])
        .filter(k => k && isTypedKeyboard(k.name));
    return typed.find(k => k.name === eventName) || typed.find(k => k.main) || typed[0];
}

function hasMultipleLayouts(keyboard) {
    return !!keyboard && typeof keyboard.layout === "string"
        && keyboard.layout.split(",").filter(layout => layout.trim().length > 0).length > 1;
}

function eventKeyboard(data) {
    const name = String(data || "").split(",", 1)[0].trim();
    return isTypedKeyboard(name) ? name : "";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { isTypedKeyboard, selectKeyboard, hasMultipleLayouts, eventKeyboard };
