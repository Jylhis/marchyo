{
  lib,
  config,
  colorSchemes,
  ...
}:
let
  cfg = config.marchyo.theme;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.scheme == null || builtins.isAttrs cfg.scheme || builtins.hasAttr cfg.scheme colorSchemes;
        message = ''
          marchyo.theme.scheme "${toString cfg.scheme}" not found in available colorSchemes.
          Use `nix eval .#lib.marchyo.colorSchemes --apply builtins.attrNames` to list custom schemes,
          or check nix-colors for built-in schemes.
        '';
      }
    ];
  };
}
