# Retired options (modules/nixos/options/removed.nix): a removed option fails
# with the replacement hint instead of an unknown-option error; a renamed one
# still lands on its upstream option.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck testNixOSFails withTestUser;

  renamedTo =
    name: check: config:
    testNixOSCheck "renamed-${name}" check (withTestUser config);
in
{
  eval-removed-launcher-vicinae-options =
    testNixOSFails "removed-launcher-vicinae-options" "Vicinae"
      (withTestUser {
        marchyo.launcher.keybinding = "vim";
      });

  eval-removed-osd = testNixOSFails "removed-osd" "SwayOSD" (withTestUser {
    marchyo.osd.enable = false;
  });

  eval-removed-gaming = testNixOSFails "removed-gaming" "gaming bundle" (withTestUser {
    marchyo.gaming.enable = true;
  });

  eval-removed-kmscon = testNixOSFails "removed-kmscon" "kmscon" (withTestUser {
    marchyo.console.kmscon.enable = true;
  });

  eval-removed-snapshots = testNixOSFails "removed-snapshots" "Snapper" (withTestUser {
    marchyo.snapshots.enable = true;
  });

  eval-removed-shell-dev-plugins =
    testNixOSFails "removed-shell-dev-plugins" "plugin dev"
      (withTestUser {
        marchyo.shell.devPlugins.enable = true;
      });

  eval-removed-shell-bar-plugin =
    testNixOSFails "removed-shell-bar-plugin" "built-in bar"
      (withTestUser {
        marchyo.shell.barPlugin = "acme.bar";
      });

  eval-removed-ai-agents = testNixOSFails "removed-ai-agents" "not carried" (withTestUser {
    marchyo.ai.agents = [ "codex" ];
  });

  eval-removed-ai-local = testNixOSFails "removed-ai-local" "Ollama" (withTestUser {
    marchyo.ai.local.enable = true;
  });

  eval-removed-ai-crash-capture =
    testNixOSFails "removed-ai-crash-capture" "Crash capture"
      (withTestUser {
        marchyo.ai.crashCapture.enable = false;
      });

  eval-removed-console = testNixOSFails "removed-console" "Quake-style" (withTestUser {
    marchyo.console.enable = false;
  });

  eval-removed-audio-tuner = testNixOSFails "removed-audio-tuner" "speaker tuner" (withTestUser {
    marchyo.audio.tuner.enable = true;
  });

  eval-removed-camlink = testNixOSFails "removed-camlink" "Cam Link" (withTestUser {
    marchyo.hardware.camlink.enable = true;
  });

  eval-removed-slack-theme-injection =
    testNixOSFails "removed-slack-theme-injection" "Slack theme"
      (withTestUser {
        marchyo.slack.themeInjection.enable = true;
      });

  eval-removed-keyboard-legacy-binds =
    testNixOSFails "removed-keyboard-legacy-binds" "only Hyprland layout"
      (withTestUser {
        marchyo.keyboard.legacyBinds = true;
      });

  eval-renamed-firewall = renamedTo "firewall" (c: !c.networking.firewall.enable) {
    marchyo.security.firewall.enable = false;
  };

  eval-renamed-resume-device = renamedTo "resume-device" (c: c.boot.resumeDevice == "/dev/sda2") {
    marchyo.power.hibernation.resumeDevice = "/dev/sda2";
  };

  eval-renamed-logitech = renamedTo "logitech" (
    c: c.programs.solaar.enable && c.hardware.logitech.wireless.enable
  ) { marchyo.hardware.logitech.enable = true; };

  eval-renamed-nvidia =
    renamedTo "nvidia"
      (
        c:
        !c.hardware.nvidia.open
        && c.hardware.nvidia.powerManagement.enable
        && !c.hardware.nvidia-container-toolkit.enable
      )
      {
        marchyo.development.enable = true;
        marchyo.graphics = {
          vendors = [ "nvidia" ];
          nvidia = {
            open = false;
            powerManagement = true;
            containerToolkit.enable = false;
          };
        };
      };

  eval-renamed-amd-overdrive = renamedTo "amd-overdrive" (c: c.hardware.amdgpu.overdrive.enable) {
    marchyo.graphics = {
      vendors = [ "amd" ];
      amd.overdrive.enable = true;
    };
  };

  eval-renamed-nix-router =
    renamedTo "nix-router"
      (
        c:
        !c.services.ncro.enable
        && c.services.ncro.port == 4300
        && c.services.ncro.netrcFile == "/etc/nix/netrc"
      )
      {
        marchyo.nix.router = {
          enable = false;
          port = 4300;
          netrcFile = "/etc/nix/netrc";
        };
      };

  eval-renamed-tailscale = renamedTo "tailscale" (c: !c.services.tailscale.enable) {
    marchyo.services.tailscale.enable = false;
  };

  eval-renamed-localsend =
    renamedTo "localsend" (c: !c.programs.localsend.enable && !c.programs.localsend.openFirewall)
      {
        marchyo.desktop.enable = true;
        marchyo.services.localsend = {
          enable = false;
          openFirewall = false;
        };
      };

  eval-removed-nvidia-package =
    testNixOSFails "removed-nvidia-package" "hardware.nvidia.package"
      (withTestUser {
        marchyo.graphics = {
          vendors = [ "nvidia" ];
          nvidia.package = "beta";
        };
      });

  eval-removed-performance-kernel =
    testNixOSFails "removed-performance-kernel" "boot.kernelPackages"
      (withTestUser {
        marchyo.performance.kernel = "zen";
      });

  eval-removed-nix-caches =
    testNixOSFails "removed-nix-caches" "nix.settings.substituters"
      (withTestUser {
        marchyo.nix.caches = [ ];
      });

  eval-removed-nix-router-extra-upstreams =
    testNixOSFails "removed-nix-router-extra-upstreams" "services.ncro.settings.upstreams"
      (withTestUser {
        marchyo.nix.router.extraUpstreams = [ ];
      });

  eval-removed-user-uid =
    testNixOSFails "removed-user-uid" "set users.users.testuser.uid"
      (withTestUser {
        marchyo.users.testuser.uid = 1000;
      });

  eval-removed-user-name =
    testNixOSFails "removed-user-name" "marchyo.users.testuser.name"
      (withTestUser {
        marchyo.users.testuser.name = "testuser";
      });

  # The retired user fields stay out of the way when unset.
  eval-removed-user-fields-unset = testNixOSCheck "removed-user-fields-unset" (
    c: lib.all (u: u.uid == null && u.name == null) (lib.attrValues c.marchyo.users)
  ) (withTestUser { });
}
