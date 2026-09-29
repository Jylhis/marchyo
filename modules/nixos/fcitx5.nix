{
  pkgs,
  lib,
  config,
  ...
}:
let
  kbdCfg = config.marchyo.keyboard;
  keyboardLib = import ../generic/keyboard-lib.nix;
  normalizedLayouts = map keyboardLib.normalizeLayout kbdCfg.layouts;

  hasIME = lib.any (l: l.ime != null) normalizedLayouts;

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

  baseAddons = with pkgs; [
    fcitx5-gtk
    fcitx5-lua
    fcitx5-table-extra
    fcitx5-table-other
  ];

  generateIMName =
    layout:
    if layout.ime != null then
      layout.ime # "pinyin", "mozc", "hangul", "unicode"
    else
      "keyboard-${layout.layout}${lib.optionalString (layout.variant != "") "-${layout.variant}"}";

  generateFcitxLayout =
    layout: if layout.variant != "" then "${layout.layout}(${layout.variant})" else layout.layout;

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
    i18n.inputMethod = {
      enable = lib.mkDefault true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = baseAddons ++ requiredAddons;

        settings = {
          inputMethod = {
            "Groups/0" = {
              "Name" = "Default";
              # Empty default layout: fcitx5 manages all layouts.
              "Default Layout" = "";
              "DefaultIM" = generateIMName (lib.head normalizedLayouts);
            };

            "GroupOrder" = {
              "0" = "Default";
            };
          }
          // inputMethodItems;

          globalOptions = {
            "Hotkey" = {
              "EnumerateWithTriggerKeys" = true;
              "AltTriggerKeys" = lib.concatStringsSep ";" kbdCfg.imeTriggerKey;
              "EnumerateSkipFirst" = false;
              "ModifierOnlyKeyTimeout" = 250;
            };

            # Primary trigger keys for switching between all inputs (layouts + IME).
            "Hotkey/TriggerKeys" = lib.listToAttrs [
              (lib.nameValuePair "0" "Super+Space")
            ];

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
              "ActiveByDefault" = kbdCfg.autoActivateIME;
              "resetStateWhenFocusIn" = "No";
              "ShareInputState" = "All";
              "PreeditEnabledByDefault" = true;
              "ShowInputMethodInformation" = true;
              "showInputMethodInformationWhenFocusIn" = false;
              "CompactInputMethodInformation" = true;
              "ShowFirstInputMethodInformation" = true;
              "DefaultPageSize" = 5;

              # Don't override XKB options (we manage them separately)
              "OverrideXkbOption" = false;
              "CustomXkbOption" = "";

              "EnabledAddons" = "";
              "DisabledAddons" = "";

              "PreloadInputMethod" = true;

              # Security: Don't allow IME in password fields
              "AllowInputMethodForPassword" = false;
              "ShowPreeditForPassword" = false;

              # Auto-save interval (minutes)
              "AutoSavePeriod" = 30;
            };

            "Behavior/DisabledAddons" = {
              # Disable quick phrase editor to avoid conflicts.
              "0" = "quickphrase-editor";
            };
          };

          addons = {
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
                "UseInputMethodLanguageToDisplayText" = true;
                "Theme" = "default";
                "ForceWaylandDPI" = 0;
              };
            };

            unicode = {
              globalSection = {
                "TriggerKey" = "Super+u";
              };
            };

            notifications = {
              globalSection = {
                "HiddenNotifications" = "";
              };
            };

            waylandim = {
              globalSection = {
                "UsePreEditForPassword" = false;
              };
            };

            clipboard = {
              globalSection = {
                "TriggerKey" = "";
                "PastePrimaryKey" = "";
                "Number of entries" = 5;
              };
            };

            pinyin = lib.mkIf (lib.any (l: l.ime == "pinyin") normalizedLayouts) {
              globalSection = {
                "PageSize" = 5;
                # Disable cloud input for privacy.
                "CloudPinyinEnabled" = false;
                "PredictionEnabled" = true;
                "PredictionSize" = 10;
              };
            };
          };
        };
      };
    };

    environment.variables = {
      # Required for X11 apps running under XWayland.
      XMODIFIERS = "@im=fcitx";

      # Qt fallback chain: Wayland text-input-v3 (native since 6.8.2), then fcitx, then ibus.
      QT_IM_MODULE = "wayland;fcitx;ibus";

      # GTK_IM_MODULE is deliberately unset: GTK 3/4 have native text-input-v3 on
      # Wayland; older GTK apps are handled via GTK settings.ini (Home Manager module).
    };

    fonts.packages = lib.mkIf hasIME (
      with pkgs;
      [
        noto-fonts
        noto-fonts-color-emoji
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ]
    );

    environment.systemPackages = with pkgs; [
      fcitx5
      qt6Packages.fcitx5-configtool
    ];
  };
}
