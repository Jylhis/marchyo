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
    readonly property string date: "date"
    readonly property string bash: "bash"
    readonly property string wtype: "wtype"
    readonly property string cliphist: "cliphist"
    readonly property string wlCopy: "wl-copy"
    readonly property string marchyo: "marchyo"
    readonly property string solaar: "solaar"
    readonly property string systemctl: "systemctl"
    readonly property string tailscale: "tailscale"
    readonly property string curl: "curl"
    readonly property string qrencode: "qrencode"
    readonly property string qalc: "qalc"
    readonly property string find: "find"
    readonly property string ps: "ps"
    readonly property string chmod: "chmod"
    readonly property string mkdir: "mkdir"
    readonly property string rm: "rm"
    readonly property string inotifywait: "inotifywait"
    readonly property string udevadm: "udevadm"
    readonly property string brightnessctl: "brightnessctl"
    readonly property string ddcutil: "ddcutil"
    readonly property string thumbs: "marchyo-thumbs"
    readonly property string language: "en"
    readonly property bool perMonitorWorkspaces: true
    readonly property bool monitorPersist: true
}
