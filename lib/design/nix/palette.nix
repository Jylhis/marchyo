# Jylhis design system — Nix palette reader.
#
# The one Nix reader of the DTCG token sources (tokens/light.tokens.json +
# tokens/dark.tokens.json). Consumers import this file instead of parsing
# token JSON themselves, so the source format can change in one place.
#
# Usage (via nix/exports.nix):
#   let p = jylhis.lib.mkPalette { mode = "dark"; }; in
#   p.hex.accent          # "#ffa028"
#   p.ansi."bright-yellow"# see tokens/dark.tokens.json
#   p.ansi16              # 16-slot bare-hex list
#   p.theme.palette.bg    # { light = "#f4efe4"; dark = "#0b0b0b"; }
#
# Or standalone:
#   import ./nix/palette.nix { lib = pkgs.lib; mode = "dark"; }
#
# Role names are the generator's: palette roles as-is (bg, accent …),
# syntax roles as syn-<name>, status roles as status-<name>, chart roles as
# chart-<name>.
{
  lib,
  mode ? "dark",
}:
let
  read = m: builtins.fromJSON (builtins.readFile (../tokens + "/${m}.tokens.json"));
  base = read "base";
  docs = {
    light = read "light";
    dark = read "dark";
    light-contrast = lib.recursiveUpdate (read "light") (read "light-contrast");
    dark-contrast = lib.recursiveUpdate (read "dark") (read "dark-contrast");
  };
  inherit (docs) light;
  modes = builtins.attrNames docs;

  # DTCG alias resolution, as in scripts/lib/resolve.mjs: a $value of
  # "{group.name}" takes the target's value, looked up in the mode file and
  # then in base, following chains. A path seen twice is an alias cycle.
  aliasPath =
    v:
    let
      m = if builtins.isString v then builtins.match "[{]([^{}]+)[}]" v else null;
    in
    if m == null then null else builtins.head m;
  resolve =
    m: seen: v:
    let
      path = aliasPath v;
      at = doc: lib.attrByPath (lib.splitString "." path) null doc;
      target = lib.findFirst (t: t != null && t ? "$value") null [
        (at docs.${m})
        (at base)
      ];
    in
    if path == null then
      v
    else if builtins.elem path seen then
      throw "palette.nix: alias cycle at {${path}}"
    else if target == null then
      throw "palette.nix: alias {${path}} has no target token"
    else
      resolve m (seen ++ [ path ]) target."$value";
  hexOf = m: tok: (resolve m [ ] tok."$value").hex;

  sh = lib.removePrefix "#";
  tokens = g: lib.filterAttrs (k: v: !(lib.hasPrefix "$" k) && v ? "$value") g;

  # DTCG group -> { <prefix><name> = { light; dark; }; }, keeping $description as notes.
  section =
    group: prefix:
    lib.mapAttrs' (
      k: tok:
      lib.nameValuePair "${prefix}${k}" (
        (lib.genAttrs modes (m: hexOf m docs.${m}.${group}.${k}))
        // lib.optionalAttrs (tok ? "$description") { notes = tok."$description"; }
      )
    ) (tokens light.${group});

  # ANSI order is the order of the JSON object, which builtins.fromJSON loses;
  # the slot names fix it.
  ansiNames = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
    "bright-black"
    "bright-red"
    "bright-green"
    "bright-yellow"
    "bright-blue"
    "bright-magenta"
    "bright-cyan"
    "bright-white"
  ];

  # Roles retired in design 4.0, kept as aliases so older readers (marchyo's
  # theme slots, the QML shells, the Hermes skin) keep evaluating. New code
  # names the live role instead.
  legacy = {
    brand = "accent";
    contour = "text-muted";
    decorator = "border-strong";
  };
  palette = section "color" "";

  theme = {
    palette = palette // lib.mapAttrs (_: role: palette.${role}) legacy;
    syntax = section "syntax" "syn-";
    status = section "status" "status-";
    chart = section "chart" "chart-";
    ansi = map (
      name:
      (lib.genAttrs modes (m: hexOf m docs.${m}.ansi.${name}))
      // {
        inherit name;
        role = light.ansi.${name}."$description" or "";
      }
    ) ansiNames;
  };
in
{
  # The colour roles in the generator's shape: { palette, syntax, status, ansi },
  # each role { light; dark; }. For consumers that need both modes at once.
  inherit theme;

  # role name → hex string for the selected mode, across
  # palette/status/syntax/chart (values keep the leading "#"; strip it yourself
  # where a target wants bare hex). e.g. hex.text == "#ffa028" (dark; light "#22201c").
  hex = lib.mapAttrs (_: tok: tok.${mode}) (
    theme.palette // theme.status // theme.syntax // theme.chart
  );

  # ANSI name → hex, e.g. ansi.black, ansi."bright-yellow".
  ansi = lib.listToAttrs (map (e: lib.nameValuePair e.name e.${mode}) theme.ansi);

  # Raw 16-slot ANSI palette as bare hex (no leading #), for terminal apps
  # that manage their own background.
  ansi16 = map (e: sh e.${mode}) theme.ansi;
}
