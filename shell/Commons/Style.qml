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

    // Jylhis spacing scale in px (tokens/base.tokens.json `space`).
    readonly property var spaceScale: ({
            "2xs": 2,
            "xs": 4,
            "sm": 8,
            "md": 16,
            "lg": 24,
            "xl": 32,
            "2xl": 48,
            "3xl": 64
        })

    // One step of the spacing scale; an unknown step reads as "sm".
    function space(step: string): int {
        const px = spaceScale[step];
        return px === undefined ? spaceScale.sm : px;
    }

    // Horizontal padding on each side of a bar segment; also the only gap
    // between segments (the bar rows use zero spacing).
    readonly property int barItemPad: space("xs")
    readonly property string baseFontFamily: "BlexMono Nerd Font"
    // Shell font: the runtime UI font (Services/RuntimeStyle, `marchyo font set
    // --kind ui`) over the baked family.
    property string uiFont: ""
    readonly property string fontFamily: uiFont !== "" ? uiFont : baseFontFamily

    // Floating pill bar (marchyo.theme.appearance.floatingBar): gap from the
    // screen edges and the bar's corner radius. Inert while floatingBar is
    // off (the strip bar spans edge to edge).
    readonly property bool barFloating: false
    readonly property int barMarginH: 0
    readonly property int barMarginV: 0
    readonly property int barRadius: 0

    // Runtime bar switches, written by Services/RuntimeStyle from
    // `marchyo theme bar-position` and `marchyo theme bar-background`. An empty
    // barBackground keeps the surfaceAlpha look below.
    property string barPosition: "top"
    property string barBackground: ""
    readonly property bool barBottom: barPosition === "bottom"
    readonly property real barAlpha: barBackground === "opaque" ? 1.0 : barBackground === "clear" ? 0.0 : barBackground === "glassy" ? Math.min(surfaceAlpha, 0.6) : surfaceAlpha

    // Glass surfaces (marchyo.theme.appearance.surfaceAlpha): opacity applied
    // to every shell card; 1.0 restores the opaque flat look (and the home
    // Hyprland config keeps blur off).
    readonly property real surfaceAlpha: 0.85

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

    // Control Center geometry: its wider card, the quick-toggle tile height,
    // and the volume/mic slider track thickness.
    readonly property int controlCenterWidth: 340
    readonly property int tileHeight: 52
    readonly property int sliderTrackHeight: 6

    // Launcher geometry (apps/emoji/clipboard card).
    readonly property int launcherWidth: 640

    // Media (MPRIS) widget: max characters of the track title shown in the bar
    // before truncation (the full title/artist stays in the tooltip).
    readonly property int mediaMaxChars: 40

    // Notification-toast geometry. Timeouts are milliseconds.
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
    // Notification-centre (history panel) max list height before it scrolls.
    readonly property int notifCenterMaxHeight: 420
    // Per-sender notification rules (baked from marchyo.notifications.rules).
    // Each: { appName?, desktopEntry?, showToast?, saveHistory?, bypassDnd?,
    // overrideDuration? (ms, -1 = default) }. Empty by default.
    readonly property var notifRules: []
    // Deck stacking by sender, verification-code detection, and the apps whose
    // notifications pass do-not-disturb (marchyo.notifications.*).
    readonly property bool notifStackBySender: true
    readonly property bool notifDetectCodes: true
    readonly property var notifPassApps: ["marchyo"]

    // Appearance scale axes (baked from marchyo.theme.appearance). Neutral
    // dev defaults; osd/panel radii and geometry above are pre-scaled by the
    // generator. animationDuration is the base transition length in ms.
    readonly property int animationDuration: 150
    readonly property bool highContrast: false
    readonly property int borderWidth: 1
    readonly property real animationSpeed: 1.0
    readonly property bool reduceMotion: false

    // Jylhis motion tokens (ms): press sink, colour ease, base, slow, long.
    // motionLong is the budget no transition may exceed (tests/shell/motion-budget-test.js).
    readonly property int motionPress: 80
    readonly property int motionFast: 150
    readonly property int motionBase: 250
    readonly property int motionSlow: 300
    readonly property int motionLong: 480

    // Runtime switches: the reduce-motion override (Services/RuntimeStyle) and
    // Hyprland's animations:enabled probe (Services/Motion).
    property bool motionRuntimeOff: false
    property bool compositorAnimationsOff: false

    // Every transition length goes through here: 0 when motion is reduced at
    // build time, by the runtime toggle, or by the compositor.
    function duration(ms: int): int {
        if (reduceMotion || motionRuntimeOff || compositorAnimationsOff)
            return 0;
        return Math.max(0, Math.round(ms / animationSpeed));
    }

    // Jylhis border tokens: hairline is borderWidth, the focus ring and the
    // selected-item marker stripe are wider.
    readonly property int borderFocus: 2
    readonly property int borderMarker: 3

    // Control states (normal, hover, focus, selected, pressed): fill colour,
    // fill alpha and border. Colours follow the live theme through Colors.
    readonly property var controls: ({
            normal: {
                fill: Colors.bgSubtle,
                fillAlpha: 1.0,
                border: Colors.border,
                borderWidth: borderWidth
            },
            hover: {
                fill: Colors.surfaceRaised,
                fillAlpha: 1.0,
                border: Colors.borderStrong,
                borderWidth: borderWidth
            },
            focus: {
                fill: Colors.bgSubtle,
                fillAlpha: 1.0,
                border: Colors.focusRing,
                borderWidth: borderFocus
            },
            selected: {
                fill: Colors.accentSubtle,
                fillAlpha: 1.0,
                border: Colors.accent,
                borderWidth: borderWidth
            },
            pressed: {
                fill: Colors.selectionBg,
                fillAlpha: 1.0,
                border: Colors.borderStrong,
                borderWidth: borderWidth
            }
        })

    function control(state: string): var {
        return controls[state] || controls.normal;
    }

    // Whether to run the solaar HID++ fallback for peripherals battery (only
    // useful with a Logitech receiver the kernel will not bind; baked from
    // marchyo.hardware.logitech.enable). Off by default so no solaar poll runs.
    readonly property bool peripheralsFallback: false

    // Baked feature flags (parity with waybar's conditional widgets). Dev default
    // shows the dictation widget; the build sets it from marchyo.dictation.
    readonly property bool dictationIndicator: true
    // marchyo.dictation.backend (voxtype).
    readonly property string dictationBackend: "voxtype"
    // Whether the gum-TUI menus feature is on (marchyo.menus.enable). Drives the
    // battery click target: `marchyo menu power` when on, else the in-shell
    // launcher's power fallback (Launcher.toggle("apps")).
    readonly property bool menusEnabled: true
}
