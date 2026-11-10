# Retired options (modules/nixos/options/removed.nix): a removed option fails
# with the replacement hint instead of an unknown-option error; a renamed one
# still lands on its upstream option.
#
# Every removed option is set at once on ONE configuration (misconfigured-3), and
# each case requires a failed assertion that names its own option path and
# carries its own hint, so the cases cannot satisfy each other. The renamed
# options are set on the tweak reference systems (refConfig below).
{ lib, ... }:
{
  failing = {
    eval-removed-launcher-vicinae-options = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.launcher.keybinding"
        "Vicinae"
      ];
    };

    eval-removed-osd = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.osd"
        "SwayOSD"
      ];
    };

    eval-removed-gaming = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.gaming"
        "gaming bundle"
      ];
    };

    eval-removed-kmscon = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.console.kmscon"
        "kmscon"
      ];
    };

    eval-removed-snapshots = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.snapshots"
        "Snapper"
      ];
    };

    eval-removed-shell-dev-plugins = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.shell.devPlugins"
        "plugin dev"
      ];
    };

    eval-removed-shell-bar-plugin = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.shell.barPlugin"
        "built-in bar"
      ];
    };

    eval-removed-ai-agents = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.ai.agents"
        "not carried"
      ];
    };

    eval-removed-ai-local = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.ai.local"
        "Ollama"
      ];
    };

    eval-removed-ai-crash-capture = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.ai.crashCapture"
        "Crash capture"
      ];
    };

    eval-removed-console = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.console.enable"
        "Quake-style"
      ];
    };

    eval-removed-audio-tuner = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.audio.tuner"
        "speaker tuner"
      ];
    };

    eval-removed-camlink = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.hardware.camlink"
        "Cam Link"
      ];
    };

    eval-removed-slack-theme-injection = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.slack.themeInjection"
        "Slack theme"
      ];
    };

    eval-removed-keyboard-legacy-binds = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.keyboard.legacyBinds"
        "only Hyprland layout"
      ];
    };

    eval-removed-nvidia-package = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.graphics.nvidia.package"
        "hardware.nvidia.package"
      ];
    };

    eval-removed-performance-kernel = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.performance.kernel"
        "boot.kernelPackages"
      ];
    };

    eval-removed-nix-caches = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.nix.caches"
        "nix.settings.substituters"
      ];
    };

    eval-removed-nix-router-extra-upstreams = {
      on = "misconfigured-3";
      expect = [
        "`marchyo.nix.router.extraUpstreams"
        "services.ncro.settings.upstreams"
      ];
    };

    eval-removed-user-uid = {
      on = "misconfigured-3";
      expect = "set users.users.testuser.uid";
    };

    eval-removed-user-name = {
      on = "misconfigured-3";
      expect = "marchyo.users.testuser.name";
    };
  };

  refs = {
    headless-tweaks-3.eval-renamed-firewall = c: !c.networking.firewall.enable;
    headless-tweaks-4 = {
      eval-renamed-resume-device = c: c.boot.resumeDevice == "/dev/sda2";
      eval-renamed-logitech = c: c.programs.solaar.enable && c.hardware.logitech.wireless.enable;
    };
    nvidia-tweaks.eval-renamed-nvidia =
      c:
      !c.hardware.nvidia.open
      && c.hardware.nvidia.powerManagement.enable
      && !c.hardware.nvidia-container-toolkit.enable;
    amd-tweaks.eval-renamed-amd-overdrive = c: c.hardware.amdgpu.overdrive.enable;
    headless-tweaks.eval-renamed-nix-router =
      c:
      !c.services.ncro.enable
      && c.services.ncro.port == 4300
      && c.services.ncro.netrcFile == "/etc/nix/netrc";
    headless-tweaks-3.eval-renamed-tailscale = c: !c.services.tailscale.enable;
    desktop-off.eval-renamed-localsend =
      c: !c.programs.localsend.enable && !c.programs.localsend.openFirewall;

    # The retired user fields stay out of the way when unset.
    headless.eval-removed-user-fields-unset =
      c: lib.all (u: u.uid == null && u.name == null) (lib.attrValues c.marchyo.users);
  };

  refConfig = {
    headless-tweaks-3.marchyo.security.firewall.enable = false;
    headless-tweaks-3.marchyo.services.tailscale.enable = false;
    headless-tweaks-4.marchyo.power.hibernation.resumeDevice = "/dev/sda2";
    headless-tweaks-4.marchyo.hardware.logitech.enable = true;
    nvidia-tweaks.marchyo.graphics.nvidia = {
      open = false;
      powerManagement = true;
      containerToolkit.enable = false;
    };
    amd-tweaks.marchyo.graphics.amd.overdrive.enable = true;
    headless-tweaks.marchyo.nix.router = {
      enable = false;
      port = 4300;
      netrcFile = "/etc/nix/netrc";
    };
    desktop-off.marchyo.services.localsend = {
      enable = false;
      openFirewall = false;
    };
  };

  # Every retired option at once, on the shared misconfigured-3 system.
  failingConfig.misconfigured-3 = {
    marchyo.launcher.keybinding = "vim";
    marchyo.osd.enable = false;
    marchyo.gaming.enable = true;
    marchyo.console.kmscon.enable = true;
    marchyo.snapshots.enable = true;
    marchyo.shell.devPlugins.enable = true;
    marchyo.shell.barPlugin = "acme.bar";
    marchyo.ai.agents = [ "codex" ];
    marchyo.ai.local.enable = true;
    marchyo.ai.crashCapture.enable = false;
    marchyo.console.enable = false;
    marchyo.audio.tuner.enable = true;
    marchyo.hardware.camlink.enable = true;
    marchyo.slack.themeInjection.enable = true;
    marchyo.keyboard.legacyBinds = true;
    marchyo.graphics.nvidia.package = "beta";
    marchyo.performance.kernel = "zen";
    marchyo.nix.caches = [ ];
    marchyo.nix.router.extraUpstreams = [ ];
    marchyo.users.testuser.uid = 1000;
    marchyo.users.testuser.name = "testuser";
  };
}
