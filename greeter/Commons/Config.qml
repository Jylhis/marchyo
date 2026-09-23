pragma Singleton
import QtQuick

// Greeter tool paths. Checked-in bare names let `quickshell -p greeter` run
// standalone during dev; the Nix build (packages/marchyo-shell/package.nix)
// overwrites this file with absolute /nix/store paths.
QtObject {
    // Greetd.launch() argv for the default session — the same command
    // tuigreet ran (uwsm resolves the hyprland-uwsm wayland session).
    readonly property var sessionCommand: ["uwsm", "start", "hyprland-uwsm.desktop"]
    readonly property string systemctl: "systemctl"
}
