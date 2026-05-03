{
  config,
  lib,
  options,
  ...
}:
{
  config.stylix = lib.mkMerge [
    {
      inherit (config.marchyo.theme) enable;
      polarity = config.marchyo.theme.variant;
    }
    (lib.mkIf (options ? stylix && options.stylix ? targets) (
      lib.mkMerge [
        (lib.optionalAttrs (options.stylix.targets ? plymouth) {
          targets.plymouth.enable = false;
        })
        (lib.optionalAttrs (options.stylix.targets ? hyprland) {
          targets.hyprland.enable = false;
        })
        (lib.optionalAttrs (options.stylix.targets ? waybar) {
          targets.waybar.enable = false;
        })
        (lib.optionalAttrs (options.stylix.targets ? mako) {
          targets.mako.enable = false;
        })
        (lib.optionalAttrs (options.stylix.targets ? ghostty) {
          targets.ghostty.enable = false;
        })
      ]
    ))
  ];
}
