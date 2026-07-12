{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 5;
  };

  # Login. The tuigreet --theme uses ANSI color names that are resolved by the
  # kernel's console palette (set in modules/nixos/console.nix from the Jylhis
  # tokens.json). Slot 11 (bright-yellow) is brand copper. Slot mapping follows
  # the greeter table in the design system's docs/INTEGRATION.md
  # (time=cyan/syn-type, button=magenta, prompt/action=brand copper).
  services.greetd = lib.mkIf cfg.desktop.enable (
    let
      tuigreetTheme = lib.concatStringsSep ";" [
        "border=brightblack"
        "text=white"
        "prompt=brightyellow"
        "time=cyan"
        "container=black"
        "greet=brightwhite"
        "input=white"
        "action=brightyellow"
        "button=magenta"
      ];
    in
    {
      enable = true;
      settings.default_session.command =
        "${lib.getExe (pkgs.tuigreet or pkgs.greetd.tuigreet)} "
        + (lib.cli.toCommandLineShellGNU { } {
          time = true;
          cmd = "uwsm start hyprland-uwsm.desktop";
          remember = true;
          remember-session = true;
          user-menu = true;
          asterisks = true;
          window-padding = 4;
          theme = tuigreetTheme;
        });
    }
  );
}
