# Stylix integration for marchyo. Imported into both NixOS and HM scope; at
# each scope it disables the Stylix targets marchyo themes directly. All writes
# are guarded on `options ? stylix` so this is a no-op for standalone Home
# Manager configs that don't import the Stylix HM module. `config.marchyo.theme`
# exists only at NixOS scope; at HM scope read `osConfig.marchyo.theme`.
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
    # aerc.nix ships its own styleset: upstream Stylix uses base07 (a background
    # slot) as a foreground, which is white-on-white in the light variant.
    "aerc"
    # vicinae.nix ships full jylhis Vicinae TOML themes and owns font.normal.* +
    # launcher_window.opacity itself.
    "vicinae"
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
