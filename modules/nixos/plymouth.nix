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
      kernelParams = lib.mkDefault [
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
