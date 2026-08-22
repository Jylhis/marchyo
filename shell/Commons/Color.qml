pragma Singleton
import QtQuick

// Jylhis design-token colors for the shell. These checked-in values are the
// Field (dark) variant so `quickshell -p shell` runs standalone during dev.
// The Nix build (packages/marchyo-shell/package.nix) overwrites this file with
// the values for the host's marchyo.theme.variant, generated from tokens.json.
QtObject {
  readonly property color background: "#0d0f14"
  readonly property color foreground: "#d6dae2"
  readonly property color accent: "#e0a33a"
}
