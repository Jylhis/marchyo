pragma Singleton
import QtQuick

// Bar geometry and font sizes. These checked-in values are for fontScale 1.0 so
// `quickshell -p shell` runs standalone during dev. The Nix build
// (packages/marchyo-shell/package.nix) overwrites this file with values scaled
// by marchyo.theme.fontScale (via lib/font-scale.nix) and the host's baked
// feature flags.
QtObject {
    readonly property int barHeight: 28
    readonly property int fontSize: 14
    readonly property int fontSizeSmall: 12
    readonly property int spacing: 4
    readonly property int paddingH: 6
    readonly property string fontFamily: "BlexMono Nerd Font"

    // On-screen-display geometry (volume/brightness overlay).
    readonly property int osdPad: 14
    readonly property int osdRadius: 8
    readonly property int osdMargin: 80
    readonly property int osdBarWidth: 140
    readonly property int osdBarHeight: 6

    // Summonable-panel geometry (audio/network/power/monitor cards under the bar).
    readonly property int panelWidth: 260
    readonly property int panelPad: 14
    readonly property int panelGap: 6
    readonly property int panelRadius: 8
    readonly property int panelRowHeight: 30

    // Notification-toast geometry (replaces mako). Timeouts are milliseconds.
    readonly property int notifWidth: 380
    readonly property int notifPad: 12
    readonly property int notifRadius: 0
    readonly property int notifBorder: 2
    readonly property int notifGap: 8
    readonly property int notifMargin: 10
    readonly property int notifIconSize: 40
    readonly property int notifMaxVisible: 5
    readonly property int notifTimeoutLow: 5000
    readonly property int notifTimeoutNormal: 5000
    readonly property int notifTimeoutCritical: 0

    // Baked feature flags (parity with waybar's conditional widgets). Dev default
    // shows the dictation widget; the build sets it from marchyo.dictation.
    readonly property bool dictationIndicator: true
    // Whether the gum-TUI menus feature is on (marchyo.menus.enable). Drives the
    // battery click target: `marchyo menu power` when on, else `vicinae toggle`.
    readonly property bool menusEnabled: true
}
