{ helpers, lib, ... }:
let
  palette = (import ../../lib/design/nix/palette.nix { inherit lib; }).theme;
  tokens = palette.palette // palette.status // palette.syntax // palette.chart;

  siteCss = lib.splitString "\n" (builtins.readFile ../../site/vendor/design/tokens.css);

  # The `--color-<name>: #rrggbb;` declarations of the block opened by `header`.
  colorsIn =
    header:
    let
      start = lib.lists.findFirstIndex (
        l: l == header
      ) (throw "no ${header} block in tokens.css") siteCss;
      rest = lib.drop (start + 1) siteCss;
      body = lib.take (lib.lists.findFirstIndex (l: l == "}") (lib.length rest) rest) rest;
      parse =
        l:
        let
          m = builtins.match "[[:space:]]+--color-([a-z0-9-]+): (#[0-9a-f]{6});.*" l;
        in
        lib.optional (m != null) (lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1));
    in
    lib.listToAttrs (lib.concatMap parse body);

  # The website imports site/vendor/design/tokens.css, generated from the same
  # token files as lib/design. Palette roles named alike in both must agree.
  cssName = n: if lib.hasPrefix "syn-" n then "syntax-${lib.removePrefix "syn-" n}" else n;
  modes = {
    light = ":root {";
    dark = "[data-mode=\"dark\"] {";
    light-contrast = ":root[data-contrast=\"more\"] {";
    dark-contrast = ":root[data-contrast=\"more\"][data-mode=\"dark\"] {";
  };
  compare =
    mode: header:
    let
      css = colorsIn header;
      shared = lib.filterAttrs (n: _: css ? ${cssName n}) tokens;
    in
    {
      count = lib.length (lib.attrNames shared);
      drift = lib.concatMap (
        n:
        lib.optional (
          css.${cssName n} != tokens.${n}.${mode}
        ) "${mode} ${n}: site ${css.${cssName n}} vs lib/design ${tokens.${n}.${mode}}"
      ) (lib.attrNames shared);
    };
  results = lib.mapAttrs compare modes;
  drift = lib.concatMap (r: r.drift) (lib.attrValues results);
  covered = lib.all (r: r.count >= 40) (lib.attrValues results);

  # Roles the shell and the theme builders read, defined in all four modes.
  everyMode = lib.all (n: lib.all (m: tokens.${n} ? ${m}) (lib.attrNames modes)) [
    "destructive-face"
    "status-warn"
    "focus-ring"
    "label"
  ];

  tokensQmlSame =
    builtins.readFile ../../shell/Commons/Tokens.qml
    == builtins.readFile ../../lib/design/platforms/quickshell/Tokens.qml;
in
{
  checks.design-vendor-sync =
    helpers.assertTest "design-vendor-sync" (drift == [ ] && covered && everyMode && tokensQmlSame)
      "site/vendor/design or shell/Commons/Tokens.qml out of step with lib/design: ${builtins.toJSON drift} covered=${lib.boolToString covered} everyMode=${lib.boolToString everyMode} tokensQmlSame=${lib.boolToString tokensQmlSame}";
}
