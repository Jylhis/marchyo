{ pkgs, lib, ... }:
{
  config = {
    boot = {
      plymouth = {
        enable = lib.mkDefault true;
        themePackages = lib.mkDefault [
          pkgs.plymouth-marchyo-theme
        ];
        theme = lib.mkDefault "marchyo";
      };
      # Run plymouth in initrd via systemd so the splash covers the entire
      # boot up to greetd-start, leaving no unthemed TTY flash visible.
      initrd = {
        systemd.enable = lib.mkDefault true;
        verbose = lib.mkDefault false;
      };
      loader.timeout = lib.mkDefault 5;
      consoleLogLevel = lib.mkDefault 0;
      # NOTE: plain (priority-100) list, NOT mkDefault. kernelParams is a list
      # option, and a mkDefault list is dropped wholesale the moment any other
      # module defines kernelParams at normal priority (e.g. performance.nix's
      # `mitigations=off`, which is on by default). A plain list merges instead.
      # Downstreams that need to drop these can still use mkForce.
      kernelParams = [
        "quiet"
        "splash"
        "loglevel=3"
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
