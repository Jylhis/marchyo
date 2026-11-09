pragma Singleton
import QtQuick
import Quickshell.Services.UPower
import qs.Commons

// Quick-settings toggle model for the Control Center: one entry per toggle,
// each binding live state from a Services/ singleton, with no presentation.
// Every entry exposes:
//   key        stable id ("wifi", "bluetooth", …)
//   icon       Nerd Font glyph for the current state
//   label      tile title
//   status     one-line state text under the title
//   active     whether the toggle reads as on
//   available  whether this host can offer it (unavailable tiles are hidden)
//   detail     panelId of the detail panel, or "" for none
//   toggle()   flip the state through the owning service
// `all` is a fixed array of these objects, so a Repeater over it never resets;
// the tiles rebind per property instead. Glyphs are written as code points
// because editing tools strip Private Use Area characters from source.
QtObject {
    id: root

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    readonly property QtObject wifi: QtObject {
        id: wifiToggle
        readonly property string key: "wifi"
        readonly property string label: I18n.t("quick.wifi")
        readonly property bool active: NetworkStatus.wifiEnabled
        readonly property bool available: NetworkStatus.wifiAvailable
        readonly property string detail: "network"
        readonly property string icon: root.glyph(wifiToggle.active ? 0xF0928 : 0xF092D)
        readonly property string status: {
            if (!NetworkStatus.wifiHardwareEnabled)
                return I18n.t("quick.hardwareOff");
            if (!wifiToggle.active)
                return I18n.t("quick.off");
            return NetworkStatus.wifi && NetworkStatus.ssid.length > 0 ? NetworkStatus.ssid : I18n.t("quick.notConnected");
        }
        function toggle(): void {
            if (NetworkStatus.wifiHardwareEnabled)
                NetworkStatus.setWifiEnabled(!wifiToggle.active);
        }
    }

    readonly property QtObject bluetooth: QtObject {
        id: bluetoothToggle
        readonly property string key: "bluetooth"
        readonly property string label: I18n.t("quick.bluetooth")
        readonly property bool active: BluetoothState.enabled
        readonly property bool available: BluetoothState.available
        readonly property string detail: ""
        readonly property string icon: root.glyph(bluetoothToggle.active ? 0xF00AF : 0xF00B2)
        readonly property string status: {
            if (!bluetoothToggle.active)
                return I18n.t("quick.off");
            const n = BluetoothState.connected.length;
            if (n === 0)
                return I18n.t("quick.noDevices");
            return n === 1 ? BluetoothState.connected[0] : I18n.tn("quick.devices", n, n);
        }
        function toggle(): void {
            BluetoothState.toggle();
        }
    }

    readonly property QtObject tailscale: QtObject {
        id: tailscaleToggle
        readonly property string key: "tailscale"
        readonly property string label: I18n.t("tailscale.title")
        readonly property bool active: Tailscale.running
        readonly property bool available: Tailscale.controllable
        readonly property string detail: "tailscale"
        readonly property string icon: root.glyph(tailscaleToggle.active ? 0xF0582 : 0xF0583)
        readonly property string status: {
            if (Tailscale.busy)
                return tailscaleToggle.active ? I18n.t("quick.disconnecting") : I18n.t("quick.connecting");
            if (Tailscale.lastError !== "")
                return Tailscale.lastError;
            if (!tailscaleToggle.active)
                return I18n.t("quick.disconnected");
            return Tailscale.exitNodeActive ? I18n.t("tailscale.exitNode", Tailscale.exitNodeName) : I18n.t("quick.connected");
        }
        function toggle(): void {
            Tailscale.setUp(!tailscaleToggle.active);
        }
    }

    readonly property QtObject dnd: QtObject {
        id: dndToggle
        readonly property string key: "dnd"
        readonly property string label: I18n.t("quick.dnd")
        readonly property bool active: NotificationState.dnd
        readonly property bool available: true
        readonly property string detail: "notifications"
        readonly property string icon: root.glyph(dndToggle.active ? 0xF009B : 0xF009A)
        readonly property string status: I18n.t(dndToggle.active ? "quick.on" : "quick.off")
        function toggle(): void {
            NotificationState.toggleDnd();
        }
    }

    readonly property QtObject caffeine: QtObject {
        id: caffeineToggle
        readonly property string key: "caffeine"
        readonly property string label: I18n.t("quick.caffeine")
        readonly property bool active: Caffeine.active
        readonly property bool available: true
        readonly property string detail: ""
        readonly property string icon: root.glyph(caffeineToggle.active ? 0xF0176 : 0xF0FAA)
        readonly property string status: caffeineToggle.active ? I18n.t("quick.screenAwake") : I18n.t("quick.off")
        function toggle(): void {
            Caffeine.toggle();
        }
    }

    readonly property QtObject nightLight: QtObject {
        id: nightLightToggle
        readonly property string key: "nightlight"
        readonly property string label: I18n.t("quick.nightLight")
        readonly property bool active: Nightlight.enabled
        readonly property bool available: true
        readonly property string detail: ""
        readonly property string icon: root.glyph(0xF050E)
        readonly property string status: nightLightToggle.active ? Nightlight.temperature + "K" : I18n.t("quick.off")
        function toggle(): void {
            Nightlight.toggle();
        }
    }

    readonly property QtObject powerProfile: QtObject {
        id: powerProfileToggle
        readonly property string key: "powerprofile"
        readonly property string label: I18n.t("power.profile")
        // Balanced is the resting state; either deviation reads as on.
        readonly property bool active: PowerProfileState.profile !== PowerProfile.Balanced
        readonly property bool available: true
        readonly property string detail: "power"
        readonly property string icon: {
            switch (PowerProfileState.profile) {
            case PowerProfile.PowerSaver:
                return root.glyph(0xF0F86);
            case PowerProfile.Performance:
                return root.glyph(0xF04C5);
            default:
                return root.glyph(0xF0F85);
            }
        }
        readonly property string status: PowerProfileState.label
        function toggle(): void {
            PowerProfileState.cycle();
        }
    }

    readonly property var all: [root.wifi, root.bluetooth, root.tailscale, root.dnd, root.caffeine, root.nightLight, root.powerProfile]
}
