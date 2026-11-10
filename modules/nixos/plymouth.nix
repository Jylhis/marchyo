# Global (headless-safe): boot splash, off unless the host opts in.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = {
    boot = {
      plymouth = {
        enable = lib.mkDefault true;
        themePackages = lib.mkDefault [
          (pkgs.plymouth-marchyo-theme.override {
            inherit (config.marchyo.theme) variant;
          })
        ];
        theme = lib.mkDefault "marchyo";
      };
      # nixpkgs' initrd is systemd-only now (scripted stage 1 is gone), so
      # plymouth already runs in initrd and covers the boot up to greetd.
      # 0 hides the systemd-boot menu; holding Space at power-on still opens it.
      loader.timeout = lib.mkDefault 0;
      consoleLogLevel = lib.mkDefault 0;
      # NOTE: plain (priority-100) list, NOT mkDefault. kernelParams is a list
      # option, and a mkDefault list is dropped wholesale the moment any other
      # module defines kernelParams at normal priority (e.g. performance.nix's
      # `mitigations=off`, which is on by default). A plain list merges instead.
      # Downstreams that need to drop these can still use mkForce. `splash` and
      # `loglevel=` come from boot.plymouth and consoleLogLevel.
      kernelParams = [
        "quiet"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        # Hide the blinking text-mode cursor that briefly appears between
        # plymouth ending and the greeter starting.
        "vt.global_cursor_default=0"
      ];
    };
  };
}
