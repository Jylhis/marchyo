{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";
in
{
  config = mkIf (cfg != null && cfg.enable && colors != null) {
    programs.bat = {
      config = {
        theme = "base16";
      };
      themes = {
        base16 = {
          src = builtins.toFile "base16.tmTheme" ''
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>name</key>
              <string>Base16</string>
              <key>settings</key>
              <array>
                <dict>
                  <key>settings</key>
                  <dict>
                    <key>background</key>
                    <string>${hex colors.base00}</string>
                    <key>foreground</key>
                    <string>${hex colors.base05}</string>
                    <key>caret</key>
                    <string>${hex colors.base05}</string>
                    <key>lineHighlight</key>
                    <string>${hex colors.base01}</string>
                    <key>selection</key>
                    <string>${hex colors.base02}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Comment</string>
                  <key>scope</key>
                  <string>comment</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base03}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>String</string>
                  <key>scope</key>
                  <string>string</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base0B}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Number</string>
                  <key>scope</key>
                  <string>constant.numeric</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base09}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Keyword</string>
                  <key>scope</key>
                  <string>keyword</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base0E}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Function</string>
                  <key>scope</key>
                  <string>entity.name.function</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base0D}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Class</string>
                  <key>scope</key>
                  <string>entity.name.class</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base0A}</string>
                  </dict>
                </dict>
                <dict>
                  <key>name</key>
                  <string>Variable</string>
                  <key>scope</key>
                  <string>variable</string>
                  <key>settings</key>
                  <dict>
                    <key>foreground</key>
                    <string>${hex colors.base08}</string>
                  </dict>
                </dict>
              </array>
            </dict>
            </plist>
          '';
        };
      };
    };
  };
}
