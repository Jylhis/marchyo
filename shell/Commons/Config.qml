pragma Singleton
import QtQuick

// Resolved external-tool paths. These checked-in bare-name values let
// `quickshell -p shell` run standalone during dev (tools found on PATH). The Nix
// build (packages/marchyo-shell/package.nix) overwrites this file with absolute
// /nix/store paths so the store shell never depends on the session PATH.
QtObject {
    readonly property string terminal: "ghostty"
    readonly property string hyprctl: "hyprctl"
    readonly property string voxtype: "voxtype"
    readonly property string wiremix: "wiremix"
    readonly property string btop: "btop"
    readonly property string nmtui: "nmtui"
    readonly property string nmcli: "nmcli"
    readonly property string bluetui: "bluetui"
    readonly property string pgrep: "pgrep"
    readonly property string ls: "ls"
    readonly property string df: "df"
    readonly property string vicinae: "vicinae"
    readonly property string marchyo: "marchyo"
}
