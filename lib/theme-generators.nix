# Runtime theme-asset generators shared by modules/home/theme-runtime.nix and
# the parity fixture check in tests/eval/theme-runtime.nix. The marchyo CLI
# (packages/marchyo-cli/packages/core/src/matugen.ts) ports the same functions
# for `marchyo theme generate`; the committed fixture
# packages/marchyo-cli/packages/core/tests/fixtures/theme-parity.json pins
# both sides to identical output. Pure string work, IFD-free.
#
# Inputs: `slots` is base00..base0F -> "#rrggbb"; `resolve` maps a kebab-case
# semantic token name to "#rrggbb".
{ lib }:
let
  hexByte = import ./hex-byte.nix { inherit lib; };
  consoleTable = import ./console-table.nix { inherit lib; };
  tmTheme = import ./base16-tmtheme.nix { inherit lib; };

  noHash = lib.removePrefix "#";
  rgb = h: "rgb(${noHash h})";
  rgba = h: a: "rgba(${noHash h}${a})";

  rgbTriple =
    h:
    map (o: toString (hexByte (builtins.substring o 2 (noHash h)))) [
      0
      2
      4
    ];

  # Token -> base16 slot. The 16 exported pairs mirror jylhis-palette.nix's
  # base16 attrset; the extras get the closest slot by role, which for a tinted
  # scheme is lossy (border/syn-comment collapse onto text-faint's base03,
  # accent-hover onto accent's base09, accent-subtle onto bg-subtle's base01).
  # `cursor` shares accent's slot because it is the same hex as accent; two
  # tokens with one build hex but different slots make a surface hex swap
  # ambiguous. A token absent from this table keeps its build-variant hex.
  # Shipped to the CLI as `tokenSlots` in every theme dir's palette.json.
  tokenSlots = {
    bg = "base00";
    "bg-subtle" = "base01";
    surface = "base02";
    "surface-raised" = "base07";
    "text-faint" = "base03";
    "text-muted" = "base04";
    text = "base05";
    "text-heading" = "base06";
    "status-err" = "base08";
    accent = "base09";
    cursor = "base09";
    "status-warn" = "base0A";
    "syn-string" = "base0B";
    "syn-type" = "base0C";
    "status-info" = "base0D";
    "syn-keyword" = "base0E";
    brand = "base0F";
    border = "base03";
    "border-strong" = "base04";
    "accent-hover" = "base09";
    "accent-subtle" = "base01";
    "status-ok" = "base0B";
    "syn-comment" = "base03";
  };

  # Token resolver for a base16 scheme: the slot when tokenSlots maps the
  # token, else the fallback (build-variant) hex.
  slotResolver =
    slots: fallback: n:
    if tokenSlots ? ${n} then slots.${tokenSlots.${n}} else fallback.${n};

  # GTK's shade_color literal, the one decimal colour in the generated css.
  shadeRgba = h: "rgba(${lib.concatStringsSep ", " (rgbTriple h)}, 0.08)";

  # Hyprland colour keywords (misc:background_color + general:col.*_border).
  hyprlandKeywordsFor = resolve: ''
    misc:background_color ${rgb (resolve "bg")}
    general:col.active_border ${rgba (resolve "accent") "ff"}
    general:col.inactive_border ${rgba (resolve "border-strong") "ff"}
  '';

  # fzf `--color` string, mirroring the role->token map in modules/home/fzf.nix.
  # `green` is the ANSI green the `marker` role uses.
  fzfOptsText =
    resolve: green:
    "--color="
    + lib.concatStringsSep "," [
      "fg:${resolve "text"}"
      "bg:${resolve "bg"}"
      "hl:${resolve "accent"}"
      "fg+:${resolve "text-heading"}"
      "bg+:${resolve "accent-subtle"}"
      "hl+:${resolve "accent-hover"}"
      "info:${resolve "text-muted"}"
      "marker:${green}"
      "prompt:${resolve "accent"}"
      "spinner:${resolve "accent"}"
      "pointer:${resolve "accent"}"
      "header:${resolve "text-muted"}"
      "border:${resolve "border"}"
      "separator:${resolve "border"}"
      "gutter:${resolve "bg"}"
    ]
    + "\n";

  # hyprlock colour include: hyprlang `$var` definitions the lock config
  # sources (modules/home/hyprlock.nix, sourceFirst).
  hyprlockVarsFor = resolve: ''
    $bg = ${rgba (resolve "bg") "ff"}
    $text = ${rgba (resolve "text") "ff"}
    $borderStrong = ${rgba (resolve "border-strong") "ff"}
    $surface = ${rgba (resolve "surface") "ff"}
    $accent = ${rgba (resolve "accent") "ff"}
    $statusErr = ${rgba (resolve "status-err") "ff"}
  '';

  # 16 console colours for a scheme: the standard base16 ANSI mapping with
  # slots 0/7/15 set to bg/text/text-heading so a bare TTY stays readable,
  # mirroring jylhis-palette.nix's tty16 overrides.
  tty16FromSlots = s: [
    s.base00 # 0  bg (override)
    s.base08
    s.base0B
    s.base0A
    s.base0D
    s.base0E
    s.base0C
    s.base05 # 7  text (override; also the standard ANSI white)
    s.base03
    s.base08
    s.base0B
    s.base0A
    s.base0D
    s.base0E
    s.base0C
    s.base06 # 15 text-heading (override)
  ];

  # Inline terminal colours (base16's standard ANSI mapping): base16 themes
  # have no named ghostty theme to reference.
  ghosttyConfFromSlots =
    s:
    let
      ansi = [
        s.base00
        s.base08
        s.base0B
        s.base0A
        s.base0D
        s.base0E
        s.base0C
        s.base05
        s.base03
        s.base08
        s.base0B
        s.base0A
        s.base0D
        s.base0E
        s.base0C
        s.base07
      ];
    in
    ''
      background = ${s.base00}
      foreground = ${s.base05}
      cursor-color = ${s.base05}
      selection-background = ${s.base02}
      selection-foreground = ${s.base05}
    ''
    + lib.concatImapStrings (i: c: "palette = ${toString (i - 1)}=${c}\n") ansi;

  # Expected output for the CLI parity fixture: every generator `marchyo theme
  # generate` ports, applied to a base16 palette and the build-variant token
  # hexes the CLI reads from palette.json.
  parityExpected =
    {
      base16,
      tokens,
      batThemeName,
    }:
    let
      resolve = slotResolver base16 tokens;
    in
    {
      "hyprlock-colors.conf" = hyprlockVarsFor resolve;
      "console.txt" = consoleTable (tty16FromSlots base16);
      "fzf.opts" = fzfOptsText resolve base16.base0B;
      "hyprland.conf" = hyprlandKeywordsFor resolve;
      "ghostty.conf" = ghosttyConfFromSlots base16;
      "bat.tmTheme" = tmTheme {
        name = batThemeName;
        slots = base16;
      };
      shade = shadeRgba (resolve "text");
      tokens = lib.genAttrs (lib.attrNames tokens) resolve;
    };
in
{
  inherit
    consoleTable
    tmTheme
    tokenSlots
    slotResolver
    shadeRgba
    hyprlandKeywordsFor
    fzfOptsText
    hyprlockVarsFor
    tty16FromSlots
    ghosttyConfFromSlots
    parityExpected
    ;
}
