{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = osConfig.marchyo.inputMethod;
in
{
  config = lib.mkIf cfg.enable {
    # Use Home Manager's built-in fcitx5 configuration options
    i18n.inputMethod = {
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = lib.optionals cfg.enableCJK (
          with pkgs;
          [
            qt6Packages.fcitx5-chinese-addons # Chinese input (Pinyin, etc.)
            fcitx5-mozc # Japanese input
            fcitx5-hangul # Korean input
          ]
        );
      };
    };

    # GTK settings for older GTK apps that don't support Wayland text-input-v3
    # Modern GTK 3/4 apps on Wayland use text-input-v3 protocol, but some older apps need this
    xdg.configFile = {
      # GTK 3 settings
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';

      # GTK 4 settings
      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';
    };

    # Custom fcitx5 configuration overrides not available in Home Manager options
    # These override the default fcitx5 settings for specific behaviors
    i18n.inputMethod.fcitx5.settings = {
      # Global fcitx5 options (corresponds to fcitx5/config)
      globalOptions = {
        "Hotkey" = {
          # Enumerate when holding modifier of Toggle key
          "EnumerateWithTriggerKeys" = true;
          # Activate/Deactivate Input Method
          "ActivateKeys" = "";
          "DeactivateKeys" = "";
          # Temporarily Toggle Input Method
          "AltTriggerKeys" = "";
          # Enumerate Input Method Forward/Backward
          "EnumerateForwardKeys" = "";
          "EnumerateBackwardKeys" = "";
          # Skip first input method while enumerating
          "EnumerateSkipFirst" = false;
          # Enumerate Input Method Group Forward/Backward
          "EnumerateGroupForwardKeys" = "";
          "EnumerateGroupBackwardKeys" = "";
          # Time limit in milliseconds for triggering modifier key shortcuts
          "ModifierOnlyKeyTimeout" = 250;
        };

        # Hotkey subsections with trigger keys and navigation
        "Hotkey/TriggerKeys" = lib.listToAttrs (
          lib.imap0 (i: key: lib.nameValuePair (toString i) key) cfg.triggerKey
        );

        "Hotkey/PrevPage" = {
          "0" = lib.mkDefault "Up";
        };

        "Hotkey/NextPage" = {
          "0" = lib.mkDefault "Down";
        };

        "Hotkey/PrevCandidate" = {
          "0" = lib.mkDefault "Shift+Tab";
        };

        "Hotkey/NextCandidate" = {
          "0" = lib.mkDefault "Tab";
        };

        "Hotkey/TogglePreedit" = {
          "0" = lib.mkDefault "Control+Alt+P";
        };

        "Behavior" = {
          # Active By Default - set to false since XKB handles basic keyboard layouts
          # fcitx5 only activates when you explicitly switch to CJK input methods
          "ActiveByDefault" = false;
          # Reset state on Focus In
          "resetStateWhenFocusIn" = "No";
          # Share Input State
          "ShareInputState" = "No";
          # Show preedit in application
          "PreeditEnabledByDefault" = true;
          # Show Input Method Information when switch input method
          "ShowInputMethodInformation" = true;
          # Show Input Method Information when changing focus
          "showInputMethodInformationWhenFocusIn" = false;
          # Show compact input method information
          "CompactInputMethodInformation" = true;
          # Show first input method information
          "ShowFirstInputMethodInformation" = true;
          # Default page size
          "DefaultPageSize" = 5;
          # Override XKB Option
          "OverrideXkbOption" = false;
          # Custom XKB Option
          "CustomXkbOption" = "";
          # Force Enabled Addons
          "EnabledAddons" = "";
          # Force Disabled Addons
          "DisabledAddons" = "";
          # Preload input method to be used by default
          "PreloadInputMethod" = true;
          # Allow input method in the password field
          "AllowInputMethodForPassword" = false;
          # Show preedit text when typing password
          "ShowPreeditForPassword" = false;
          # Interval of saving user data in minutes
          "AutoSavePeriod" = 30;
        };

        "Behavior/DisabledAddons" = {
          # Disable modules that might interfere
          "0" = "quickphrase-editor";
        };
      };

      # Input method profile
      # Note: Basic keyboard layouts (US, Finnish, etc.) are handled by XKB
      # fcitx5 is only used for CJK input methods and Unicode picker
      inputMethod = {
        "Groups/0" = {
          "Name" = "Default";
          # Empty default layout - keyboard layouts managed by XKB
          "Default Layout" = "";
          # Default IM depends on whether CJK is enabled
          "DefaultIM" = if cfg.enableCJK then "pinyin" else "unicode";
        };

        "GroupOrder" = {
          "0" = "Default";
        };
      }
      // (
        if cfg.enableCJK then
          {
            # When CJK enabled: Pinyin, Mozc, Hangul, Unicode
            "Groups/0/Items/0" = {
              "Name" = "pinyin";
              "Layout" = "";
            };

            "Groups/0/Items/1" = {
              "Name" = "mozc";
              "Layout" = "";
            };

            "Groups/0/Items/2" = {
              "Name" = "hangul";
              "Layout" = "";
            };

            "Groups/0/Items/3" = {
              "Name" = "unicode";
              "Layout" = "";
            };
          }
        else
          {
            # When CJK disabled: Only Unicode
            "Groups/0/Items/0" = {
              "Name" = "unicode";
              "Layout" = "";
            };
          }
      );

      # Addon-specific configurations
      addons = {
        # Classic UI (appearance) settings
        classicui = {
          globalSection = {
            "Vertical Candidate List" = false;
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
            # Custom trigger key for Unicode picker
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

        # Clipboard integration
        clipboard = {
          globalSection = {
            # Disabled by default to avoid conflicts
            "TriggerKey" = "";
            "PastePrimaryKey" = "";
            "Number of entries" = 5;
          };
        };

        # Pinyin configuration (CJK)
        pinyin = lib.mkIf cfg.enableCJK {
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
}
