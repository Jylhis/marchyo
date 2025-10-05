{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.marchyo.updateNotifications;
  inherit (lib)
    mkOption
    mkIf
    types
    getExe
    ;

  # Script to check for flake updates and send notifications
  updateCheckScript = pkgs.writeShellScript "check-flake-updates" ''
    set -euo pipefail

    # Configuration file location (where the flake is)
    FLAKE_PATH="/etc/nixos"

    # Check if flake exists
    if [[ ! -f "$FLAKE_PATH/flake.nix" ]]; then
      echo "No flake found at $FLAKE_PATH"
      exit 0
    fi

    # Fetch latest flake metadata from upstream
    # This will update the flake metadata cache without modifying flake.lock
    ${getExe pkgs.nix} flake metadata "$FLAKE_PATH" --refresh > /dev/null 2>&1 || true

    # Check if there are any updates available by comparing flake.lock
    # We do this by running 'nix flake update --dry-run' and checking output
    UPDATE_OUTPUT=$(${getExe pkgs.nix} flake lock "$FLAKE_PATH" --dry-run 2>&1 || true)

    # Count how many inputs would be updated
    # Look for lines like "Updated 'nixpkgs': ..." or "• Updated ..."
    UPDATE_COUNT=$(echo "$UPDATE_OUTPUT" | grep -i "updated\|updating" | wc -l || echo "0")

    # If updates are available, send notification
    if [[ "$UPDATE_COUNT" -gt 0 ]]; then
      # Get list of packages that would be updated
      NOTIFICATION_BODY="$UPDATE_COUNT flake input(s) have updates available.\n\nRun 'nix flake update' to update."

      # Use the configured notification command
      # Default to notify-send if running in a user session with DISPLAY/WAYLAND_DISPLAY
      if [[ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
        ${cfg.notificationCommand} \
          "NixOS Updates Available" \
          "$NOTIFICATION_BODY" \
          --urgency=normal \
          --icon=system-software-update \
          --app-name="NixOS Update Checker"
      else
        echo "Updates available but no display session found"
        echo "$NOTIFICATION_BODY"
      fi
    else
      echo "No updates available"
    fi
  '';

  # Determine timer schedule based on frequency
  timerSchedule =
    if cfg.frequency == "daily" then
      "daily"
    else if cfg.frequency == "weekly" then
      "weekly"
    else if cfg.frequency == "monthly" then
      "monthly"
    else
      "daily"; # fallback to daily
in
{
  options.marchyo.updateNotifications = {
    enable = mkOption {
      type = types.bool;
      # Default to true when desktop is enabled, false otherwise
      default = config.marchyo.desktop.enable;
      defaultText = lib.literalExpression "config.marchyo.desktop.enable";
      description = ''
        Enable automatic update notifications for NixOS flake updates.

        When enabled, a systemd timer will periodically check for available
        updates to the system flake inputs and send desktop notifications
        when updates are available.

        Defaults to true when desktop environment is enabled.
      '';
    };

    frequency = mkOption {
      type = types.enum [
        "daily"
        "weekly"
        "monthly"
      ];
      default = "daily";
      description = ''
        How often to check for updates.

        - daily: Check once per day
        - weekly: Check once per week
        - monthly: Check once per month
      '';
    };

    checkOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to check for updates automatically after system boot.

        When enabled, the update check will run 5 minutes after boot
        to avoid interfering with system startup.
      '';
    };

    notificationCommand = mkOption {
      type = types.str;
      default = "${getExe pkgs.libnotify}";
      defaultText = lib.literalExpression ''"''${lib.getExe pkgs.libnotify}"'';
      description = ''
        Command to use for sending desktop notifications.

        The command will be called with the following arguments:
          <title> <body> --urgency=normal --icon=system-software-update --app-name="NixOS Update Checker"

        Defaults to notify-send from libnotify package.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Systemd service that runs the update check
    systemd.services.nixos-update-check = {
      description = "Check for NixOS flake updates";
      serviceConfig = {
        Type = "oneshot";
        # Run as root to access /etc/nixos and nix commands
        User = "root";
        # Ensure we have network access for fetching flake metadata
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      # Execute the update check script
      script = "${updateCheckScript}";

      # Ensure the service can send notifications to user sessions
      environment = {
        # Allow the script to detect user sessions
        XDG_RUNTIME_DIR = "/run/user/1000"; # Assumes first user is UID 1000
      };
    };

    # Systemd timer for periodic update checks
    systemd.timers.nixos-update-check = {
      description = "Timer for NixOS update checks";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Run based on configured frequency
        OnCalendar = timerSchedule;
        # Add some randomization to avoid all systems checking at once
        RandomizedDelaySec = "1h";
        # Persist timer state across reboots
        Persistent = true;
        # If system was off during scheduled time, run on next boot
        OnBootSec = mkIf cfg.checkOnBoot "5min";
      };
    };

    # Ensure required packages are available
    environment.systemPackages = [
      pkgs.libnotify # Provides notify-send
      pkgs.nix # Ensure nix command is available
    ];
  };
}
