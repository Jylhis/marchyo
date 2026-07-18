# Omarchy-style "Trigger" utilities (OMARCHY_PARITY.md Phase 3): gum-driven
# reminders backed by transient systemd user timers. Scripts follow the
# window-toggles.nix wrapper pattern; the binds merge into
# wayland.windowManager.hyprland.settings the same way webapps.nix contributes
# its launch binds (list-valued Hyprland settings concatenate across Home
# Manager modules, so hyprland.nix stays untouched).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && (marchyoCfg.desktop.enable or false);
  # `or true` mirrors the option defaults (desktop-cascade opt-outs).
  remindersEnabled = desktopEnabled && ((marchyoCfg.reminders or { }).enable or true);

  # Interactive reminder entry: message + delay via gum, scheduled as a
  # transient one-shot systemd user timer that fires a critical notification.
  marchyo-reminder-set = pkgs.writeShellApplication {
    name = "marchyo-reminder-set";
    runtimeInputs = [
      pkgs.gum
      pkgs.libnotify
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      msg=$(gum input --prompt "Reminder: " --placeholder "Remind me to...") || exit 0
      [ -n "$msg" ] || exit 0
      delay=$(gum input --prompt "In: " --placeholder "10m, 2h, 1h30m..." --value "10m") || exit 0
      [ -n "$delay" ] || exit 0

      # The transient unit fires outside this script's PATH, so notify-send is
      # referenced by store path. %N keeps same-second reminders from
      # colliding on the unit name.
      systemd-run --user --on-active="$delay" \
        --unit="marchyo-reminder-$(date +%s%N)" \
        --description="marchyo reminder: $msg" \
        ${lib.getExe' pkgs.libnotify "notify-send"} -u critical "Reminder" "$msg"

      statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo"
      mkdir -p "$statedir"
      printf '%s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M')" "$delay" "$msg" >> "$statedir/reminders"
      notify-send -u low -a marchyo "Reminder set" "In $delay: $msg"
    '';
  };

  # Pending timers + the append-only log, paged in the floating terminal.
  marchyo-reminder-show = pkgs.writeShellApplication {
    name = "marchyo-reminder-show";
    runtimeInputs = [
      pkgs.gum
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      statefile="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/reminders"
      {
        echo "Pending reminders:"
        systemctl --user list-timers --all 'marchyo-reminder-*' --no-pager || true
        echo
        echo "Reminder log:"
        if [ -s "$statefile" ]; then
          cat "$statefile"
        else
          echo "(empty)"
        fi
      } | gum pager
    '';
  };

  marchyo-reminder-clear = pkgs.writeShellApplication {
    name = "marchyo-reminder-clear";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      # The wildcard covers both the transient .timer units and any .service
      # units already spawned by an elapsed timer.
      systemctl --user stop 'marchyo-reminder-*' || true
      statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo"
      mkdir -p "$statedir"
      : > "$statedir/reminders"
      notify-send -u low -a marchyo "Reminders" "Cleared pending reminders"
    '';
  };

  # Interactive scripts run in the floating terminal (the keybindings-cheatsheet
  # pattern: org.omarchy.terminal picks up the centered floating-window rule).
  reminderBinds = [
    "SUPER CTRL, R, Set reminder, exec, $terminal --class=org.omarchy.terminal -e marchyo-reminder-set"
    "SUPER CTRL ALT, R, Show reminders, exec, $terminal --class=org.omarchy.terminal -e marchyo-reminder-show"
    "SUPER CTRL SHIFT, R, Clear reminders, exec, marchyo-reminder-clear"
  ];
in
{
  config = lib.mkIf remindersEnabled {
    home.packages = [
      marchyo-reminder-set
      marchyo-reminder-show
      marchyo-reminder-clear
    ];
    wayland.windowManager.hyprland.settings.bindd = reminderBinds;
  };
}
