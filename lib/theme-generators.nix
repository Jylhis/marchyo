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
  # selection-bg, destructive and the syn-* extras take the slot the base16
  # styling guidelines name for their role: base02 "Selection Background",
  # base08 "Variables" and "Diff Deleted" (the red slot), base09 "Integers",
  # base0C "Support" (built-ins), base0D "Functions". `cursor` shares
  # accent's slot because it is the same hex as accent; two tokens with one
  # build hex but different slots make a surface hex swap ambiguous. A token
  # absent from this table (contour, decorator, scrim, syn-docstring: no
  # base16 role) keeps its build-variant hex. Shipped to the CLI as
  # `tokenSlots` in every theme dir's palette.json.
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
    "selection-bg" = "base02";
    destructive = "base08";
    "syn-variable" = "base08";
    "syn-number" = "base09";
    "syn-builtin" = "base0C";
    "syn-function" = "base0D";
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

  # Long-tail TUI surfaces themed from base16 slots alone (k9s, lazygit,
  # spotify-player, gdu). Each returns the config data the build-time module in
  # modules/home/ hands to Home Manager; the `*Text` renderers below serialize
  # the same data for the runtime theme dirs.
  k9sSkinFromSlots = s: {
    k9s = {
      body = {
        fgColor = s.base05;
        bgColor = "default";
        logoColor = s.base0C;
      };
      prompt = {
        fgColor = s.base05;
        bgColor = "default";
        suggestColor = s.base02;
      };
      info = {
        fgColor = s.base0B;
        sectionColor = s.base05;
      };
      # base11 (the Stylix dialog focus slot) is absent from catalog schemes;
      # base00 stands in.
      dialog = {
        fgColor = s.base05;
        bgColor = s.base01;
        buttonFgColor = s.base05;
        buttonBgColor = s.base02;
        buttonFocusFgColor = s.base00;
        buttonFocusBgColor = s.base0B;
        labelFgColor = s.base0A;
        fieldFgColor = s.base05;
      };
      frame = {
        border = {
          fgColor = s.base02;
          focusColor = s.base01;
        };
        menu = {
          fgColor = s.base05;
          keyColor = s.base0B;
          numKeyColor = s.base0B;
        };
        crumbs = {
          fgColor = s.base05;
          bgColor = s.base01;
          activeColor = s.base02;
        };
        status = {
          newColor = s.base0C;
          modifyColor = s.base09;
          addColor = s.base0B;
          errorColor = s.base08;
          highlightcolor = s.base0A;
          killColor = s.base03;
          completedColor = s.base03;
        };
        title = {
          fgColor = s.base05;
          bgColor = s.base01;
          highlightColor = s.base0A;
          counterColor = s.base0C;
          filterColor = s.base0B;
        };
      };
      views = {
        charts = {
          bgColor = "default";
          defaultDialColors = [
            s.base0C
            s.base0D
          ];
          defaultChartColors = [
            s.base0C
            s.base0D
          ];
        };
        table = {
          fgColor = s.base05;
          bgColor = "default";
          header = {
            fgColor = s.base05;
            bgColor = "default";
            sorterColor = s.base08;
          };
        };
        xray = {
          fgColor = s.base05;
          bgColor = "default";
          cursorColor = s.base01;
          graphicColor = s.base0C;
          showIcons = false;
        };
        yaml = {
          keyColor = s.base08;
          colonColor = s.base05;
          valueColor = s.base0B;
        };
        logs = {
          fgColor = s.base05;
          bgColor = "default";
          indicator = {
            fgColor = s.base05;
            bgColor = "default";
            toggleOnColor = s.base0B;
            toggleOffColor = s.base04;
          };
        };
        help = {
          fgColor = s.base05;
          bgColor = "default";
          indicator.fgColor = s.base0D;
        };
      };
    };
  };

  # lazygit `gui.theme`.
  lazygitThemeFromSlots = s: {
    activeBorderColor = [
      s.base0D
      "bold"
    ];
    inactiveBorderColor = [ s.base03 ];
    searchingActiveBorderColor = [
      s.base04
      "bold"
    ];
    optionsTextColor = [ s.base06 ];
    selectedLineBgColor = [ s.base03 ];
    cherryPickedCommitBgColor = [ s.base02 ];
    cherryPickedCommitFgColor = [ s.base03 ];
    unstagedChangesColor = [ s.base08 ];
    defaultFgColor = [ s.base05 ];
  };

  # spotify-player theme palette.
  spotifyPlayerPaletteFromSlots = s: {
    background = s.base00;
    foreground = s.base05;
    black = s.base00;
    red = s.base08;
    green = s.base0B;
    yellow = s.base0A;
    blue = s.base0D;
    magenta = s.base0E;
    cyan = s.base0C;
    white = s.base05;
    bright_black = s.base03;
    bright_red = s.base08;
    bright_green = s.base0B;
    bright_yellow = s.base0A;
    bright_blue = s.base0D;
    bright_magenta = s.base0E;
    bright_cyan = s.base0C;
    bright_white = s.base07;
  };

  # Block-style YAML for nested attrsets of strings, bools and string lists,
  # keys in attrNames (byte) order. Strings are JSON-quoted, which YAML reads
  # as double-quoted scalars.
  yamlText =
    let
      scalar =
        v:
        if builtins.isBool v then
          lib.boolToString v
        else if builtins.isList v then
          "[" + lib.concatMapStringsSep ", " scalar v + "]"
        else
          builtins.toJSON v;
      lines =
        indent: attrs:
        lib.concatMap (
          k:
          let
            v = attrs.${k};
          in
          if builtins.isAttrs v then
            [ "${indent}${k}:" ] ++ lines "${indent}  " v
          else
            [ "${indent}${k}: ${scalar v}" ]
        ) (lib.attrNames attrs);
    in
    attrs: lib.concatMapStrings (l: l + "\n") (lines "" attrs);

  k9sSkinText = s: yamlText (k9sSkinFromSlots s);

  # Merged over the main lazygit config via LG_CONFIG_FILE.
  lazygitText = s: yamlText { gui.theme = lazygitThemeFromSlots s; };

  # spotify-player theme.toml with the one `jylhis` theme its app.toml selects.
  spotifyPlayerThemeText =
    s:
    let
      palette = spotifyPlayerPaletteFromSlots s;
    in
    ''
      [[themes]]
      name = "jylhis"

      [themes.palette]
    ''
    + lib.concatMapStrings (k: "${k} = ${builtins.toJSON palette.${k}}\n") (lib.attrNames palette);

  # gdu.yaml; the file carries only the theme.
  gduText = s: ''
    style:
      selected-row:
        text-color: "${s.base05}"
        background-color: "${s.base00}"
      result-row:
        number-color: "${s.base06}"
        directory-color: "${s.base02}"
      footer:
        text-color: "${s.base05}"
        background-color: "${s.base00}"
        number-color: "${s.base06}"
      header:
        text-color: "${s.base05}"
        background-color: "${s.base00}"
  '';

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
      "k9s-skin.yaml" = k9sSkinText base16;
      "lazygit.yml" = lazygitText base16;
      "spotify-player-theme.toml" = spotifyPlayerThemeText base16;
      "gdu.yaml" = gduText base16;
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
    k9sSkinFromSlots
    lazygitThemeFromSlots
    spotifyPlayerPaletteFromSlots
    yamlText
    k9sSkinText
    lazygitText
    spotifyPlayerThemeText
    gduText
    parityExpected
    ;
}
