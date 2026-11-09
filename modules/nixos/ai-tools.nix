{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.ai;
  unfreeOk = config.nixpkgs.config.allowUnfree;
  unfreeMessage = what: ''
    ${what} is unfree software and nixpkgs.config.allowUnfree is false.
    Set nixpkgs.config.allowUnfree = true, or disable the option.
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.herdr.enable {
      environment.systemPackages = [ pkgs.herdr ];
    })

    (lib.mkIf cfg.herdr.desktop.enable {
      environment.systemPackages = [ pkgs.herdr-app ];
    })

    (lib.mkIf cfg.amp.enable {
      assertions = [
        {
          assertion = unfreeOk;
          message = unfreeMessage "marchyo.ai.amp.enable (amp-cli)";
        }
      ];
      environment.systemPackages = lib.optionals unfreeOk [ pkgs.amp-cli ];
    })

    (lib.mkIf cfg.amp.desktop.enable {
      assertions = [
        {
          assertion = unfreeOk;
          message = unfreeMessage "marchyo.ai.amp.desktop.enable (amp-desktop)";
        }
      ];
      environment.systemPackages = lib.optionals unfreeOk [ pkgs.amp-desktop ];
    })
  ];
}
