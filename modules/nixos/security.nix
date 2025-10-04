{
  security = {
    # Polkit Configuration
    polkit = {
      enable = true;
      debug = false; # Set to true to see rule evaluation logs

      # Custom polkit rules for common system operations
      #   extraConfig = ''
      #     // Allow users in wheel group to execute actions without password for certain operations
      #     polkit.addRule(function(action, subject) {
      #       if (subject.isInGroup("wheel")) {
      #         // Network management
      #         if (action.id == "org.freedesktop.NetworkManager.settings.modify.system" ||
      #             action.id == "org.freedesktop.NetworkManager.network-control" ||
      #             action.id == "org.freedesktop.NetworkManager.enable-disable-network" ||
      #             action.id == "org.freedesktop.NetworkManager.enable-disable-wifi") {
      #           return polkit.Result.YES;
      #         }

      #         // Power management
      #         if (action.id == "org.freedesktop.login1.power-off" ||
      #             action.id == "org.freedesktop.login1.reboot" ||
      #             action.id == "org.freedesktop.login1.suspend" ||
      #             action.id == "org.freedesktop.login1.hibernate") {
      #           return polkit.Result.YES;
      #         }

      #         // Package management (for wheel group, require auth but allow)
      #         if (action.id == "org.nixos.nix.store" ||
      #             action.id.indexOf("org.freedesktop.packagekit") == 0) {
      #           return polkit.Result.AUTH_ADMIN_KEEP;
      #         }
      #       }

      #       return polkit.Result.NOT_HANDLED;
      #     });

      #     // Allow users to manage their own systemd user services
      #     polkit.addRule(function(action, subject) {
      #       if (action.id == "org.freedesktop.systemd1.manage-unit-files" ||
      #           action.id == "org.freedesktop.systemd1.manage-units") {
      #         if (action.lookup("unit").indexOf(subject.user) == 0) {
      #           return polkit.Result.YES;
      #         }
      #       }

      #       return polkit.Result.NOT_HANDLED;
      #     });

      #     // Storage management - allow wheel users to mount/unmount
      #     polkit.addRule(function(action, subject) {
      #       if (subject.isInGroup("wheel")) {
      #         if (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
      #             action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
      #             action.id == "org.freedesktop.udisks2.filesystem-unmount") {
      #           return polkit.Result.YES;
      #         }
      #       }

      #       return polkit.Result.NOT_HANDLED;
      #     });
      #   '';
      # };

      # # Real-time Kit (already enabled, keeping for audio/video priority)
      # rtkit.enable = true;

      # # PAM Configuration
      # pam = {
      #   # Login limits for resource management
      #   loginLimits = [
      #     # Prevent fork bombs
      #     {
      #       domain = "*";
      #       type = "hard";
      #       item = "nproc";
      #       value = "4096";
      #     }
      #     {
      #       domain = "*";
      #       type = "soft";
      #       item = "nproc";
      #       value = "2048";
      #     }

      #     # File descriptor limits
      #     {
      #       domain = "*";
      #       type = "hard";
      #       item = "nofile";
      #       value = "524288";
      #     }
      #     {
      #       domain = "*";
      #       type = "soft";
      #       item = "nofile";
      #       value = "262144";
      #     }

      #     # Core dumps (disable for security)
      #     {
      #       domain = "*";
      #       type = "hard";
      #       item = "core";
      #       value = "0";
      #     }

      #     # Memory lock limits (for applications that need it)
      #     {
      #       domain = "@wheel";
      #       type = "soft";
      #       item = "memlock";
      #       value = "unlimited";
      #     }
      #     {
      #       domain = "@wheel";
      #       type = "hard";
      #       item = "memlock";
      #       value = "unlimited";
      #     }

      #     # Max logins per user
      #     {
      #       domain = "*";
      #       type = "-";
      #       item = "maxlogins";
      #       value = "10";
      #     }
      #   ];

      #   # U2F/FIDO2 Support (optional, enable if hardware keys are used)
      #   # Uncomment to enable:
      #   # u2f = {
      #   #   enable = true;
      #   #   control = "sufficient"; # Use "required" for mandatory 2FA
      #   #   settings = {
      #   #     cue = true; # Prompt user to touch the key
      #   #     authfile = "/etc/u2f-mappings"; # Centralized key database
      #   #     # origin = "pam://nixos"; # Set consistent origin for key reuse
      #   #   };
      #   # };

      #   # Service-specific PAM configurations
      #   services = {
      #     # Sudo configuration - require authentication
      #     sudo = {
      #       sshAgentAuth = false; # Disable SSH agent auth for sudo (security)
      #       # For SSH agent auth on remote systems, set to true
      #     };

      #     # Login configuration
      #     login = {
      #       limits = [
      #         # Additional login-specific limits
      #         {
      #           domain = "*";
      #           type = "soft";
      #           item = "maxlogins";
      #           value = "5";
      #         }
      #       ];
      #     };

      #     # SSHD configuration
      #     sshd = {
      #       # Enable SSH agent forwarding authentication if needed
      #       # sshAgentAuth = true;
      #     };
      #   };
      # };

      # # Sudo configuration
      # sudo = {
      #   enable = true;
      #   wheelNeedsPassword = true; # Require password for sudo
      #   execWheelOnly = true; # Only wheel group can execute sudo (CVE-2021-3156 mitigation)

      #   extraConfig = ''
      #     # Security defaults
      #     Defaults lecture = never
      #     Defaults pwfeedback
      #     Defaults passwd_timeout=15
      #     Defaults timestamp_timeout=15
      #     Defaults insults

      #     # Environment preservation
      #     Defaults env_keep += "SSH_AUTH_SOCK"
      #     Defaults env_keep += "EDITOR"

      #     # Logging
      #     Defaults log_input
      #     Defaults log_output
      #     Defaults logfile=/var/log/sudo.log
      #   '';
    };
  };
}
