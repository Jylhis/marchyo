# NixOS fcitx5 configuration (system-level)
#
# This module sets up fcitx5 input method framework at the system level.
# User-specific configuration is in modules/home/fcitx5.nix
#
# What this module does:
# - Enables i18n.inputMethod.fcitx5 with Wayland frontend support
# - Installs fcitx5 addons (GTK integration, CJK input methods, etc.)
# - Sets environment variables for X11/Xwayland and Qt applications
# - Installs required fonts for Unicode and CJK display
# - Installs fcitx5-configtool for GUI configuration
#
# Environment variable strategy:
# - XMODIFIERS: For X11/Xwayland applications
# - QT_IM_MODULE: Fallback chain for Qt (wayland;fcitx;ibus)
# - GTK_IM_MODULE: NOT set globally (set per-app via GTK settings.ini in Home Manager)
#   This allows modern GTK apps to use Wayland text-input-v3 protocol
#
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
    # Note: User-level configuration is in modules/home/fcitx5.nix
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

    # Environment variables for input method integration
    # Modern approach for Wayland with fallback for X11/Xwayland apps
    environment.variables = {
      # XWayland and X11 support - REQUIRED for X11 apps
      XMODIFIERS = "@im=fcitx";

      # Qt input method configuration
      # Qt 6.7+: Fallback chain tries Wayland protocol first, then fcitx
      # Qt 6.8.2+: Has native text-input-v3 Wayland support
      # For older Qt apps under Xwayland, fcitx is used
      QT_IM_MODULE = "wayland;fcitx;ibus";

      # Note: GTK_IM_MODULE is NOT set as an environment variable
      # Instead, it's configured via GTK settings.ini files in the Home Manager module
      # (see modules/home/fcitx5.nix: gtk-3.0/settings.ini and gtk-4.0/settings.ini)
      # This sets gtk-im-module=fcitx for all GTK 3 and GTK 4 applications globally.
      #
      # While modern GTK 3.24+ and GTK 4 have native Wayland text-input-v3 support,
      # we configure the fcitx IM module globally for maximum compatibility.
      # GTK apps may still use text-input-v3 if fcitx5's Wayland IM frontend is active.
    };

    # Enable fcitx5 input method support at the display manager level
    # This ensures fcitx5 works at the login screen and across all sessions
    environment.sessionVariables = {
      # These variables are set for all user sessions, including login screen
      GLFW_IM_MODULE = "fcitx"; # For GLFW applications (some games, ImGui apps, etc.)
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

    # Install fcitx5 configuration tool at system level
    # Note: fcitx5 itself is automatically installed via i18n.inputMethod.fcitx5
    # Installing it again in systemPackages can cause conflicts in some NixOS versions
    environment.systemPackages = with pkgs; [
      qt6Packages.fcitx5-configtool # GUI configuration tool
    ];
  };
}
