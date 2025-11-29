{
  pkgs,
  lib,
  config,
  ...
}:
let
  kbdCfg = config.marchyo.keyboard;

  # Normalize all layouts to uniform structure
  normalizedLayouts = map (
    layout:
    if builtins.isString layout then
      {
        inherit layout;
        variant = "";
        ime = null;
        label = null;
      }
    else
      layout
  ) kbdCfg.layouts;

  # Check if any layout requires IME
  hasIME = lib.any (l: l.ime != null) normalizedLayouts;

  # Determine required fcitx5 addons based on IME usage
  requiredAddons = lib.unique (
    lib.flatten (
      map (
        l:
        if l.ime == "pinyin" then
          [ pkgs.qt6Packages.fcitx5-chinese-addons ]
        else if l.ime == "mozc" then
          [ pkgs.fcitx5-mozc ]
        else if l.ime == "hangul" then
          [ pkgs.fcitx5-hangul ]
        else
          [ ]
      ) normalizedLayouts
    )
  );

  # Base addons always included
  baseAddons = with pkgs; [
    fcitx5-gtk # GTK2/3/4 integration
    fcitx5-lua # Scripting support
    fcitx5-table-extra # Extra input tables
    fcitx5-table-other # Additional input tables
  ];

  # Generate fcitx5 input method name from layout
  generateIMName =
    layout:
    if layout.ime != null then
      layout.ime # "pinyin", "mozc", "hangul", "unicode"
    else
      "keyboard-${layout.layout}${lib.optionalString (layout.variant != "") "-${layout.variant}"}";

  # Generate fcitx5 keyboard layout spec
  generateFcitxLayout =
    layout: if layout.variant != "" then "${layout.layout}(${layout.variant})" else layout.layout;

  # Generate input method items for fcitx5 profile
  inputMethodItems = lib.listToAttrs (
    lib.imap0 (
      i: layout:
      lib.nameValuePair "Groups/0/Items/${toString i}" {
        "Name" = generateIMName layout;
        # Empty layout for IME (fcitx5 handles it), otherwise use keyboard layout
        "Layout" = if layout.ime != null then "" else generateFcitxLayout layout;
      }
    ) normalizedLayouts
  );
in
{
  config = lib.mkIf (kbdCfg.layouts != [ ]) {
    # Always enable fcitx5 when layouts are configured
    # This provides unified input management for both simple layouts and IME
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = baseAddons ++ requiredAddons;

        # Generate fcitx5 configuration from marchyo.keyboard.layouts
        settings = {
          # Input method profile
          inputMethod = {
            "Groups/0" = {
              "Name" = "Default";
              # Empty default layout - fcitx5 manages all layouts
              "Default Layout" = "";
              # Default to first layout
              "DefaultIM" = generateIMName (lib.head normalizedLayouts);
            };

            "GroupOrder" = {
              "0" = "Default";
            };
          }
          // inputMethodItems;

          # Global fcitx5 options
          globalOptions = {
            # Hotkey settings
            "Hotkey" = {
              "EnumerateWithTriggerKeys" = true;
              "AltTriggerKeys" = lib.concatStringsSep ";" kbdCfg.imeTriggerKey;
              "EnumerateSkipFirst" = false;
              "ModifierOnlyKeyTimeout" = 250;
            };

            # Primary trigger keys for switching between all inputs (layouts + IME)
            # Uses Super+Space by default (from marchyo.keyboard.options)
            "Hotkey/TriggerKeys" = lib.listToAttrs [
              (lib.nameValuePair "0" "Super+Space")
            ];

            # Navigation keys for candidate selection
            "Hotkey/PrevPage" = lib.listToAttrs [
              (lib.nameValuePair "0" (lib.mkDefault "Up"))
            ];
            "Hotkey/NextPage" = lib.listToAttrs [
              (lib.nameValuePair "0" (lib.mkDefault "Down"))
            ];
            "Hotkey/PrevCandidate" = lib.listToAttrs [
              (lib.nameValuePair "0" (lib.mkDefault "Shift+Tab"))
            ];
            "Hotkey/NextCandidate" = lib.listToAttrs [
              (lib.nameValuePair "0" (lib.mkDefault "Tab"))
            ];
            "Hotkey/TogglePreedit" = lib.listToAttrs [
              (lib.nameValuePair "0" (lib.mkDefault "Control+Alt+P"))
            ];

            "Behavior" = {
              # Auto-activate IME when switching to layout with IME
              "ActiveByDefault" = kbdCfg.autoActivateIME;

              # Reset state on focus in
              "resetStateWhenFocusIn" = "No";

              # Share input state across all windows for consistency
              "ShareInputState" = "All";

              # Show preedit in application
              "PreeditEnabledByDefault" = true;

              # Show input method information when switching
              "ShowInputMethodInformation" = true;
              "showInputMethodInformationWhenFocusIn" = false;
              "CompactInputMethodInformation" = true;
              "ShowFirstInputMethodInformation" = true;

              # Default page size for candidates
              "DefaultPageSize" = 5;

              # Don't override XKB options (we manage them separately)
              "OverrideXkbOption" = false;
              "CustomXkbOption" = "";

              # Force enabled/disabled addons
              "EnabledAddons" = "";
              "DisabledAddons" = "";

              # Preload input methods for faster activation
              "PreloadInputMethod" = true;

              # Security: Don't allow IME in password fields
              "AllowInputMethodForPassword" = false;
              "ShowPreeditForPassword" = false;

              # Auto-save interval (minutes)
              "AutoSavePeriod" = 30;
            };

            "Behavior/DisabledAddons" = {
              # Disable quick phrase editor to avoid conflicts
              "0" = "quickphrase-editor";
            };
          };

          # Addon-specific configurations
          addons = {
            # Classic UI appearance settings
            classicui = {
              globalSection = {
                "Vertical Candidate List" = false; # Horizontal layout
                "PerScreenDPI" = true;
                "EnableBlur" = false;
                "Font" = "Sans 10";
                "MenuFont" = "Sans 10";
                "TrayFont" = "Sans Bold 10";
                "PreferTextIcon" = false;
                "ShowLayoutNameInIcon" = true;
                "UseInputMethodLangaugeToDisplayText" = true;
                "Theme" = "default";
                "ForceWaylandDPI" = 0;
              };
            };

            # Unicode character picker
            unicode = {
              globalSection = {
                "TriggerKey" = "Super+u";
              };
            };

            # Notifications
            notifications = {
              globalSection = {
                "HiddenNotifications" = "";
              };
            };

            # Wayland input method protocol
            waylandim = {
              globalSection = {
                "UsePreEditForPassword" = false;
              };
            };

            # Clipboard integration (disabled by default)
            clipboard = {
              globalSection = {
                "TriggerKey" = "";
                "PastePrimaryKey" = "";
                "Number of entries" = 5;
              };
            };

            # Pinyin configuration (when Chinese IME is enabled)
            pinyin = lib.mkIf (lib.any (l: l.ime == "pinyin") normalizedLayouts) {
              globalSection = {
                "PageSize" = 5;
                # Disable cloud input for privacy
                "CloudPinyinEnabled" = false;
                "PredictionEnabled" = true;
                "PredictionSize" = 10;
              };
            };
          };
        };
      };
    };

    # Environment variables for application compatibility
    environment.variables = {
      # XWayland support - REQUIRED for X11 apps running under Wayland
      XMODIFIERS = "@im=fcitx";

      # Qt 6.7+ fallback chain - tries Wayland protocol first, then fcitx, then ibus
      # Qt 6.8.2+ has native text-input-v3 support
      QT_IM_MODULE = "wayland;fcitx;ibus";

      # Note: GTK_IM_MODULE is NOT set globally
      # - GTK 3/4 have native text-input-v3 support on Wayland
      # - For older GTK apps, configure via GTK settings.ini (see Home Manager module)
    };

    # Install required fonts for Unicode and CJK display (when IME is used)
    fonts.packages = lib.mkIf hasIME (
      with pkgs;
      [
        # Unicode support
        noto-fonts
        noto-fonts-color-emoji

        # CJK fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ]
    );

    # Install fcitx5 and config tool at system level
    environment.systemPackages = with pkgs; [
      fcitx5
      qt6Packages.fcitx5-configtool
    ];
  };
}
