# Welcome message module for Marchyo
# Displays a welcome banner on first boot or login
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.welcome;

  # Welcome script that displays ASCII art and system information
  welcomeScript = pkgs.writeShellScript "marchyo-welcome" ''
    # Path to the marker file
    WELCOME_FILE="$HOME/.marchyo-welcomed"

    # Check if we should show the welcome message
    if [ ! -f "$WELCOME_FILE" ] || [ "${toString cfg.showOnEveryBoot}" = "1" ]; then
      # ASCII art banner
      echo ""
      echo "  __  __                 _                "
      echo " |  \/  | __ _ _ __ ___| |__  _   _  ___  "
      echo " | |\/| |/ _\` | '__/ __| '_ \| | | |/ _ \ "
      echo " | |  | | (_| | | | (__| | | | |_| | (_) |"
      echo " |_|  |_|\__,_|_|  \___|_| |_|\__, |\___/ "
      echo "                               |___/       "
      echo ""
      echo "Welcome to Marchyo - Your NixOS Configuration"
      echo "=============================================="
      echo ""

      # System information
      echo "System Information:"
      echo "  Hostname: $(${lib.getExe pkgs.hostname})"
      echo "  NixOS Version: $(${lib.getExe pkgs.coreutils} cat /etc/os-release | ${lib.getExe pkgs.gnugrep} VERSION= | ${lib.getExe pkgs.coreutils} cut -d'"' -f2)"
      echo "  Kernel: $(${lib.getExe pkgs.coreutils} uname -r)"
      echo ""

      # Helpful links
      echo "Helpful Links:"
      echo "  Documentation: https://github.com/Jylhis/marchyo"
      echo "  Report Issues: https://github.com/Jylhis/marchyo/issues"
      echo ""

      # Quick commands
      echo "Quick Commands:"
      echo "  Run 'health' to check system health"
      echo "  Run 'update' to update the system"
      echo "  Run 'help marchyo' for more commands"
      echo ""

      # Create marker file to prevent showing again (unless showOnEveryBoot is true)
      if [ "${toString cfg.showOnEveryBoot}" != "1" ]; then
        touch "$WELCOME_FILE"
      fi
    fi
  '';
in
{
  # Option definitions
  options.marchyo.welcome = {
    enable = lib.mkEnableOption "Marchyo welcome message on first boot" // {
      default = true;
    };

    showOnEveryBoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to show the welcome message on every boot/login.
        When false, the message is only shown once (until ~/.marchyo-welcomed is deleted).
        When true, the message is always displayed.
      '';
    };
  };

  # Configuration implementation
  config = lib.mkIf cfg.enable {
    # Bash shell integration
    programs.bash.initExtra = lib.mkAfter ''
      # Display Marchyo welcome message
      ${welcomeScript}
    '';

    # Fish shell integration
    programs.fish.interactiveShellInit = lib.mkAfter ''
      # Display Marchyo welcome message
      ${welcomeScript}
    '';

    # Zsh shell integration (if enabled)
    programs.zsh.initExtra = lib.mkAfter ''
      # Display Marchyo welcome message
      ${welcomeScript}
    '';
  };
}
