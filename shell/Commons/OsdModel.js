function iconFor(kind, percent) {
    if (kind === "mute")
        return "";
    if (kind === "micMute")
        return "󰍭";
    if (kind === "mic")
        return "󰍬";
    if (kind === "brightness")
        return "󰍹";
    if (kind === "volume")
        return percent <= 0 ? "" : percent <= 33 ? "" : percent <= 66 ? "" : "";
    return "";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {iconFor: iconFor};
