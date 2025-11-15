{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.inputMethod;
in
{
  config = lib.mkIf cfg.enable {
    # Enable system-level input method framework
    # User-level configuration is in modules/home/fcitx5.nix
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;

        addons =
          with pkgs;
          [
            fcitx5-gtk # GTK2/3/4 integration

            # Enhancement addons
            fcitx5-lua # Scripting support for custom functionality
            fcitx5-table-extra # Extra input tables for various languages
            fcitx5-table-other # Additional input tables
          ]
          ++ (lib.optionals cfg.enableCJK [
            qt6Packages.fcitx5-chinese-addons # Chinese input (Pinyin, etc.)
            fcitx5-mozc # Japanese input
            fcitx5-hangul # Korean input
          ]);
      };
    };

    environment.variables = {
      # XWayland support - REQUIRED for X11 apps running under Wayland
      XMODIFIERS = "@im=fcitx";

      # Qt 6.7+ fallback chain - tries Wayland protocol first, then fcitx, then ibus
      # Qt 6.8.2+ has native text-input-v3 support
      QT_IM_MODULE = "wayland;fcitx;ibus";

      # Note: GTK_IM_MODULE is NOT set globally
      # - GTK 3/4 have native text-input-v3 support on Wayland
      # - For older GTK apps that need it, configure via GTK settings.ini (see Home Manager module)
    };

    # Install required fonts for Unicode and CJK display
    fonts.packages = with pkgs; [
      # Unicode support
      noto-fonts
      noto-fonts-color-emoji

      # CJK fonts (installed regardless of enableCJK for better Unicode coverage)
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];

    # Install fcitx5 and config tool at system level
    environment.systemPackages = with pkgs; [
      fcitx5
      qt6Packages.fcitx5-configtool
    ];
  };
}
