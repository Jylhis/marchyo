#!/usr/bin/env bash
# Dark/Light mode toggle script for Hyprland
# Switches between light and dark themes for GTK, Qt, and Hyprland

set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/theme-mode"

# Ensure state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Read current mode, default to dark
current_mode=$(cat "$STATE_FILE" 2>/dev/null || echo "dark")

# Toggle mode
if [ "$current_mode" = "dark" ]; then
    new_mode="light"
else
    new_mode="dark"
fi

# Save new mode
echo "$new_mode" > "$STATE_FILE"

# Update GTK theme
if [ "$new_mode" = "light" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    qt_theme="adwaita"
else
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    qt_theme="adwaita-dark"
fi

# Update Qt theme via environment (requires app restart)
# This is mainly informational; apps need to be restarted to pick up the change
export QT_STYLE_OVERRIDE="$qt_theme"

# Update Hyprland border colors
if [ "$new_mode" = "light" ]; then
    # Light mode colors
    hyprctl keyword general:col.active_border "rgba(3584E4ee) rgba(1A73E8ee) 45deg"
    hyprctl keyword general:col.inactive_border "rgba(C0C0C0aa)"
else
    # Dark mode colors
    hyprctl keyword general:col.active_border "rgba(33ccffee) rgba(00ff99ee) 45deg"
    hyprctl keyword general:col.inactive_border "rgba(595959aa)"
fi

# Reload waybar to pick up theme changes
if pgrep -x waybar > /dev/null; then
    pkill -SIGUSR2 waybar
fi

# Notify user
notify-send "Theme switched" "Now using $new_mode mode" -t 2000 -a "Marchyo Theme"

exit 0
