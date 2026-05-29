# macOS system defaults: keyboard/input parity with marchyo's Linux config.
_: {
  system.defaults = {
    # Fn key: Change Input Source
    hitoolbox.AppleFnUsageType = "Change Input Source";

    # Disable input source keyboard shortcuts (Ctrl+Space / Ctrl+Option+Space)
    CustomUserPreferences."com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        "60" = {
          enabled = false;
          value = {
            parameters = [
              32
              49
              262144
            ];
            type = "standard";
          };
        };
        "61" = {
          enabled = false;
          value = {
            parameters = [
              32
              49
              786432
            ];
            type = "standard";
          };
        };
      };
    };
  };

  # Swap Caps Lock and Control (matches the Linux `ctrl:swapcaps` XKB option).
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };
}
