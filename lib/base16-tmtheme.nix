# Generate a bat/Sublime `.tmTheme` (plist) from a base16 slot set.
#
# Used for runtime theme switching of bat: the Jylhis pair reuses the richer
# hand-tuned tmThemes shipped in pkgs.jylhis-themes, but tinted-schemes catalog
# and inline base16 entries have no shipped tmTheme, so this templates one from
# their 16 slots using the canonical base16 scope->slot mapping (the same
# mapping Chris Kempson's base16 textmate template uses). Pure string
# generation, no import-from-derivation.
#
# `slots` is base00..base0F -> "#rrggbb"; `name` is the human-readable theme
# name embedded in the plist (bat keys themes by filename stem, not this).
{ lib }:
{
  name,
  slots,
}:
let
  s = slots;
  scope = scopeName: selector: color: ''
    <dict>
      <key>name</key><string>${scopeName}</string>
      <key>scope</key><string>${selector}</string>
      <key>settings</key><dict><key>foreground</key><string>${color}</string></dict>
    </dict>'';
in
''
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>name</key>
    <string>${name}</string>
    <key>settings</key>
    <array>
      <dict>
        <key>settings</key>
        <dict>
          <key>background</key><string>${s.base00}</string>
          <key>foreground</key><string>${s.base05}</string>
          <key>caret</key><string>${s.base05}</string>
          <key>selection</key><string>${s.base02}</string>
          <key>lineHighlight</key><string>${s.base01}</string>
          <key>gutterForeground</key><string>${s.base03}</string>
        </dict>
      </dict>
  ${lib.concatStringsSep "\n" [
    (scope "Comment" "comment, punctuation.definition.comment" s.base03)
    (scope "String" "string, constant.other.symbol" s.base0B)
    (scope "Number" "constant.numeric, constant.language" s.base09)
    (scope "Constant" "constant, support.constant" s.base09)
    (scope "Keyword" "keyword, storage.type, storage.modifier" s.base0E)
    (scope "Operator" "keyword.operator, punctuation" s.base05)
    (scope "Function" "entity.name.function, support.function" s.base0D)
    (scope "Type" "entity.name.type, entity.name.class, support.type, support.class" s.base0A)
    (scope "Variable" "variable, variable.parameter" s.base08)
    (scope "Tag" "entity.name.tag" s.base08)
    (scope "Attribute" "entity.other.attribute-name" s.base09)
    (scope "Invalid" "invalid, invalid.illegal" s.base08)
  ]}
    </array>
  </dict>
  </plist>
''
