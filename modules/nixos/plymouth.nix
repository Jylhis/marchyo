{ pkgs, lib, ... }:
{
  config = {
    boot = {
      plymouth = {
        enable = lib.mkDefault true;
        themePackages = lib.mkDefault [
          (pkgs.callPackage ../../packages/plymouth-marchyo-theme/package.nix { })
        ];
        theme = lib.mkDefault "marchyo";
      };
      initrd.verbose = lib.mkDefault false;
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
      ];
    };
  };
}
