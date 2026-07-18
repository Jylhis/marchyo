# Omarchy-style "Trigger" utilities (OMARCHY_PARITY.md Phase 3): gum-driven
# reminders backed by transient systemd user timers, quick-info
# notifications (date/time, battery), and a media transcode + share pair.
# Scripts follow the window-toggles.nix wrapper pattern; the binds merge into
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
  utilitiesEnabled = desktopEnabled && ((marchyoCfg.utilities or { }).enable or true);

  # Bash snippet shared by the reminder scripts (expanded at runtime).
  stateDirSnippet = ''statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo"'';

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
      # colliding on the unit name. systemd-run rejects malformed time spans,
      # so surface that instead of dying silently.
      if ! systemd-run --user --on-active="$delay" \
        --unit="marchyo-reminder-$(date +%s%N)" \
        --description="marchyo reminder: $msg" \
        ${lib.getExe' pkgs.libnotify "notify-send"} -u critical "Reminder" "$msg"; then
        notify-send -u critical -a marchyo "Reminder" "Could not schedule reminder - is \"$delay\" a valid delay?"
        exit 1
      fi

      ${stateDirSnippet}
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
      ${stateDirSnippet}
      statefile="$statedir/reminders"
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
      ${stateDirSnippet}
      mkdir -p "$statedir"
      : > "$statedir/reminders"
      notify-send -u low -a marchyo "Reminders" "Cleared pending reminders"
    '';
  };

  marchyo-notify-datetime = pkgs.writeShellApplication {
    name = "marchyo-notify-datetime";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      notify-send -u low -a marchyo "$(date '+%A %-d %B')" "$(date '+%H:%M')"
    '';
  };

  marchyo-notify-battery = pkgs.writeShellApplication {
    name = "marchyo-notify-battery";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      found=0
      for bat in /sys/class/power_supply/BAT*; do
        # Both reads are guarded: an unreadable sysfs node under `set -e`
        # would otherwise abort the script before the fallback below.
        if [ ! -r "$bat/capacity" ] || [ ! -r "$bat/status" ]; then
          continue
        fi
        found=1
        capacity=$(cat "$bat/capacity")
        status=$(cat "$bat/status")
        urgency=low
        if [ "$status" = "Discharging" ] && [ "$capacity" -le 20 ]; then
          urgency=critical
        fi
        notify-send -u "$urgency" -a marchyo "Battery $capacity%" "$(basename "$bat"): $status"
      done
      if [ "$found" -eq 0 ]; then
        notify-send -u low -a marchyo "Battery" "No battery detected"
      fi
    '';
  };

  # Optional ascii mode: pkgs.terminaltexteffects (the `tte` binary) is in
  # current nixpkgs (verified in OMARCHY_PARITY.md); the `?` guard keeps
  # evaluation safe if it is ever dropped or renamed.
  hasTte = pkgs ? terminaltexteffects;

  marchyo-transcode = pkgs.writeShellApplication {
    name = "marchyo-transcode";
    runtimeInputs = [
      pkgs.gum
      pkgs.ffmpeg
      pkgs.libnotify
      pkgs.coreutils
    ]
    ++ lib.optional hasTte pkgs.terminaltexteffects;
    text = ''
      src="''${1:-}"
      if [ -z "$src" ]; then
        src=$(gum file "$HOME") || exit 0
      fi
      if [ ! -f "$src" ]; then
        echo "marchyo-transcode: not a file: $src" >&2
        exit 1
      fi

      choices=(mp4 webm gif)
      ${lib.optionalString hasTte ''choices+=("ascii (tte)")''}
      target=$(gum choose --header "Transcode to" "''${choices[@]}") || exit 0

      dir=$(dirname "$src")
      stem=$(basename "$src")
      stem="''${stem%.*}"
      # Transcode lands next to the source; dodge in-place overwrites when the
      # source already has the target extension.
      out="$dir/$stem.$target"
      if [ "$out" = "$src" ]; then
        out="$dir/$stem.transcoded.$target"
      fi

      case "$target" in
        mp4)
          args=(-c:v libx264 -preset fast -crf 23 -c:a aac)
          ;;
        webm)
          args=(-c:v libvpx-vp9 -crf 32 -b:v 0 -c:a libopus)
          ;;
        gif)
          args=(-vf "fps=12,scale=640:-1:flags=lanczos")
          ;;
        "ascii (tte)")
          # Text-mode "transcode": animate the file's text in the terminal
          # with terminaltexteffects. No output file is produced.
          tte beams < "$src"
          exit 0
          ;;
      esac
      if ! ffmpeg -y -i "$src" "''${args[@]}" "$out"; then
        notify-send -u critical -a marchyo "Transcode" "ffmpeg failed transcoding $(basename "$src")"
        exit 1
      fi
      notify-send -u low -a marchyo "Transcode" "Saved $(basename "$out")"
    '';
  };

  # Copies the chosen content/path to the clipboard; an actual upload target
  # is deferred (follow-up decision per OMARCHY_PARITY.md). No keybinding -
  # reached from the central menu.
  marchyo-share = pkgs.writeShellApplication {
    name = "marchyo-share";
    runtimeInputs = [
      pkgs.gum
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      choice=$(gum choose --header "Share" Clipboard File Folder) || exit 0
      case "$choice" in
        Clipboard)
          # The clipboard already holds the content; nothing more to stage
          # until an upload target lands.
          notify-send -u low -a marchyo "Share" "Clipboard content ready to paste"
          ;;
        File)
          file=$(gum file "$HOME") || exit 0
          wl-copy < "$file"
          notify-send -u low -a marchyo "Share" "Copied contents of $(basename "$file")"
          ;;
        Folder)
          # --directory lets gum's picker select directories too.
          folder=$(gum file --directory "$HOME") || exit 0
          printf '%s' "$folder" | wl-copy
          notify-send -u low -a marchyo "Share" "Copied path $folder"
          ;;
      esac
    '';
  };

  # Interactive scripts run in the floating terminal (the keybindings-cheatsheet
  # pattern: org.omarchy.terminal picks up the centered floating-window rule);
  # the notify wrappers run directly.
  reminderBinds = [
    "SUPER CTRL, R, Set reminder, exec, $terminal --class=org.omarchy.terminal -e marchyo-reminder-set"
    "SUPER CTRL ALT, R, Show reminders, exec, $terminal --class=org.omarchy.terminal -e marchyo-reminder-show"
    "SUPER CTRL SHIFT, R, Clear reminders, exec, marchyo-reminder-clear"
  ];
  utilityBinds = [
    "SUPER CTRL ALT, T, Show date and time, exec, marchyo-notify-datetime"
    "SUPER CTRL ALT, B, Show battery status, exec, marchyo-notify-battery"
    "SUPER CTRL, period, Transcode media, exec, $terminal --class=org.omarchy.terminal -e marchyo-transcode"
  ];
in
{
  config = lib.mkMerge [
    (lib.mkIf remindersEnabled {
      home.packages = [
        marchyo-reminder-set
        marchyo-reminder-show
        marchyo-reminder-clear
      ];
      wayland.windowManager.hyprland.settings.bindd = reminderBinds;
    })
    (lib.mkIf utilitiesEnabled {
      home.packages = [
        marchyo-notify-datetime
        marchyo-notify-battery
        marchyo-transcode
        marchyo-share
      ];
      wayland.windowManager.hyprland.settings.bindd = utilityBinds;
    })
  ];
}
