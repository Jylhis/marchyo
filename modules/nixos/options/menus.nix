# Power/session and central system menu options (platform-neutral
# declarations; the implementation lives in modules/home/menus.nix).
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.menus = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Power/session and central system menus (auto-enabled with desktop).";
    };
  };
}
