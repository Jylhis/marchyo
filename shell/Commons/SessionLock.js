// Pure reading of the compositor's session-lock state for Services/Lock.
//
// Same dual-citizenship arrangement as Format.js (see its header): QML imports
// this directly and ignores the CommonJS guard at the bottom, Node loads it as
// an ordinary module, so tests/shell/session-lock-test.js runs under
// `nix flake check`. Must stay pure: the caller passes `hyprctl -j monitors`
// output in.
//
// ext-session-lock outlives its client, so a restarted shell reads this to
// notice an orphaned lock and take it back (Hyprland's
// misc.allow_session_lock_restore).
//
// Hyprland reports no lock state directly, but an active session lock is one of
// the reasons a monitor cannot go solitary: LOCK in solitaryBlockedBy. It stays
// set after the lock client dies, which is the case to detect. Hyprland stops at
// the first reason on a monitor with no workspace yet (WORKSPACE), before it
// reaches the lock, so such a monitor says nothing either way.

// "locked", "unlocked" or "unknown" for one `hyprctl -j monitors` reply.
function lockState(monitorsJson) {
    var monitors;
    try {
        monitors = JSON.parse(monitorsJson);
    } catch (e) {
        return "unknown";
    }
    if (!Array.isArray(monitors))
        return "unknown";

    var readable = false;
    for (var i = 0; i < monitors.length; i++) {
        var blockers = (monitors[i] && monitors[i].solitaryBlockedBy) || [];
        if (blockers.indexOf("LOCK") !== -1)
            return "locked";
        if (blockers.indexOf("WORKSPACE") === -1)
            readable = true;
    }
    return readable ? "unlocked" : "unknown";
}

function ignoreRepeat(autoRepeat, editingKey) {
    return autoRepeat && !editingKey;
}

if (typeof module !== "undefined")
    module.exports = {
        ignoreRepeat: ignoreRepeat,
        lockState: lockState
    };
