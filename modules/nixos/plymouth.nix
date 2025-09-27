{ pkgs, ... }:
{
  config = {
    boot = {
      plymouth = {
        enable = true;
        themePackages = [
          (pkgs.callPackage ../../packages/plymouth-marchyo-theme/package.nix { })
        ];
        theme = "marchyo";
      };
      initrd.verbose = false;
      loader.timeout = 5;
      consoleLogLevel = 0;
      kernelParams = [
        "quiet"
        "splash"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "boot.shell_on_fail"
        "udev.log_priority=3"
      ];
    };
  };
}
