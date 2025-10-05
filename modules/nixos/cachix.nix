{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkDefault
    mkMerge
    ;
  cfg = config.marchyo.cachix;
in
{
  options.marchyo.cachix = {
    enable = mkEnableOption "Marchyo binary cache configuration" // {
      default = true;
    };

    enableNixCommunity = mkEnableOption "popular community binary caches (nix-community)" // {
      default = true;
    };
  };

  config = mkMerge [
    # Marchyo and Hyprland caches
    (mkIf cfg.enable {
      nix.settings = {
        substituters = mkDefault [
          # Marchyo binary cache
          "https://marchyo.cachix.org"
          # Hyprland cache for Wayland compositor
          "https://hyprland.cachix.org"
        ];

        trusted-public-keys = mkDefault [
          # Marchyo cache public key
          "marchyo.cachix.org-1:qBhWfBnfkWFfPe0XpPPeCQc3+KKQXHmLQQKH+PUfx3I="
          # Hyprland cache public key
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };
    })

    # Community caches
    (mkIf (cfg.enable && cfg.enableNixCommunity) {
      nix.settings = {
        substituters = mkDefault [
          # Nix community cache for popular packages
          "https://nix-community.cachix.org"
        ];

        trusted-public-keys = mkDefault [
          # Nix community cache public key
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
    })
  ];
}
