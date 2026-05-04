# Stylix integration for marchyo.
#
# Imported into BOTH NixOS scope (modules/nixos/default.nix) and HM scope
# (modules/home/default.nix). At each scope it disables the Stylix targets that
# exist in that scope and that marchyo themes directly (either via the upstream
# Jylhis HM module or hand-rolled).
#
# All writes are guarded on `options ? stylix` so this module is a no-op for
# standalone Home Manager configurations that don't import the Stylix HM module
# (e.g. the homeConfigurations smoke-test outputs).
#
# `config.marchyo.theme` is only present at NixOS scope; at HM scope we read
# `osConfig.marchyo.theme` (with safe fallbacks for standalone HM evals).
{
  config,
  lib,
  options,
  osConfig ? { },
  ...
}:
let
  hasStylix = options ? stylix;
  hasStylixTargets = hasStylix && options.stylix ? targets;

  hasNixosMarchyo = options ? marchyo && options.marchyo ? theme;
  marchyoTheme =
    if hasNixosMarchyo then
      config.marchyo.theme
    else
      (osConfig.marchyo or { }).theme or {
        enable = true;
        variant = "dark";
      };

  disabledTargets = [
    "plymouth"
    "hyprland"
    "waybar"
    "mako"
    "ghostty"
    "gtk"
    "fzf"
    "bat"
    "hyprlock"
    "console"
    "starship"
  ];

  targetDisable = lib.mkMerge (
    map (
      name:
      lib.optionalAttrs (hasStylixTargets && options.stylix.targets ? ${name}) {
        targets.${name}.enable = false;
      }
    ) disabledTargets
  );
in
{
  config = lib.optionalAttrs hasStylix {
    stylix = lib.mkMerge [
      {
        inherit (marchyoTheme) enable;
        polarity = marchyoTheme.variant;
      }
      targetDisable
    ];
  };
}
