// XDG base-directory resolution, shared by Commons/Theme.qml and
// Commons/ShellConfig.qml (three call sites across $XDG_CONFIG_HOME and
// $XDG_STATE_HOME).
//
// Same dual-citizenship arrangement as Format.js (see its header): QML imports
// this directly and ignores the CommonJS guard at the bottom. Must stay pure:
// no Qt types, no globals, no I/O: the caller passes the env values in, since
// Quickshell.env is not available to Node.

// $XDG_<X>_HOME if set, else `fallback` under $HOME. Per the basedir spec an
// env var set to the empty string counts as unset, which a plain truthiness
// check would already catch but a `!== undefined` check would not.
function xdgDir(envValue, home, fallback) {
    return envValue && envValue !== "" ? envValue : (home ?? "") + fallback;
}

// Node (tests) picks this up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        xdgDir: xdgDir
    };
