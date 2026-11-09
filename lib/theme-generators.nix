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
  hexByte = lib.fromHexString;
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

  # Token -> base16 slot, by role as in jylhis-palette.nix's base16 attrset
  # (mirrors BASE16 in lib/design/scripts/lib/terminal.mjs, design-desktop(7)):
  # base00 bg, base01 bg-subtle, base02 selection-bg, base03 text-faint, base04
  # text-muted, base05 text, base06 text-heading, base07 text-heading again,
  # base08 status-err, base09 syn-number, base0A status-warn, base0B
  # syn-string, base0C syn-type, base0D syn-function, base0E syn-keyword, base0F
  # syn-docstring. base07 is "The Lightest Foreground" (ANSI 15, bright white),
  # so no ground takes it and text-heading keeps base06.
  # Extras take the slot of the role they share a hex with: since design 5.0
  # accent, link, rule and focus-ring (light) are the ink, so they take base05
  # (text); accent-hover is text-heading (base06), accent-subtle is selection-bg
  # (base02). Two tokens with one build hex but different slots would make a
  # surface hex swap ambiguous, so the aliases follow their target. Lossy
  # leftovers: surface and surface-raised fall to base01 (nearest ground),
  # border to base03 and border-strong to base04, destructive to base08 (the
  # red slot). Tokens with no base16 role are left out and keep their
  # build-variant hex: primary and its on-/hi/lo/edge shades, cursor (an alias
  # of primary), the bevels, the chart colours, scrim, status-info,
  # link-underline-hover. That is the least surprising choice: the signal is
  # the design's own and a tinted scheme has no counterpart for it. Shipped to
  # the CLI as `tokenSlots` in every theme dir's palette.json.
  tokenSlots = {
    bg = "base00";
    "bg-subtle" = "base01";
    surface = "base01";
    "surface-raised" = "base01";
    "text-faint" = "base03";
    "text-muted" = "base04";
    text = "base05";
    "text-heading" = "base06";
    "status-err" = "base08";
    "syn-number" = "base09";
    "status-warn" = "base0A";
    "syn-string" = "base0B";
    "syn-type" = "base0C";
    "syn-function" = "base0D";
    "syn-keyword" = "base0E";
    "syn-docstring" = "base0F";
    accent = "base05";
    link = "base05";
    rule = "base05";
    "chart-ink" = "base05";
    brand = "base05";
    contour = "base04";
    decorator = "base04";
    border = "base03";
    "border-strong" = "base04";
    "accent-hover" = "base06";
    "accent-subtle" = "base02";
    "status-ok" = "base0B";
    "syn-comment" = "base03";
    "selection-bg" = "base02";
    destructive = "base08";
    "syn-variable" = "base08";
    "syn-builtin" = "base0C";
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

  # fzf `--color` string, mirroring the role->token map in modules/home/fzf.nix
  # and emitFzf in lib/design/scripts/lib/terminal.mjs. Links are ink, so a
  # match is marked by weight and underline, not hue.
  # `green` is the ANSI green the `marker` role uses.
  fzfOptsText =
    resolve: green:
    "--color="
    + lib.concatStringsSep "," [
      "fg:${resolve "text"}"
      "bg:${resolve "bg"}"
      "hl:${resolve "text"}:underline:bold"
      "fg+:${resolve "text-heading"}"
      "bg+:${resolve "selection-bg"}"
      "hl+:${resolve "text-heading"}:underline:bold"
      "info:${resolve "text-muted"}"
      "marker:${green}"
      "prompt:${resolve "text"}"
      "spinner:${resolve "text-muted"}"
      "pointer:${resolve "rule"}"
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

  # Application theme surfaces (VS Code family, Obsidian, tmux, Slack, fcitx5,
  # herdr), all from base16 slots. JSON surfaces go through builtins.toJSON
  # (sorted keys); core/src/matugen.ts ports each one byte for byte.
  jsonText = v: builtins.toJSON v + "\n";

  vscodeAnsiNames = [
    "Black"
    "Red"
    "Green"
    "Yellow"
    "Blue"
    "Magenta"
    "Cyan"
    "White"
    "BrightBlack"
    "BrightRed"
    "BrightGreen"
    "BrightYellow"
    "BrightBlue"
    "BrightMagenta"
    "BrightCyan"
    "BrightWhite"
  ];

  # A complete VS Code colour theme. The generated extension ships it as
  # themes/marchyo-color-theme.json.
  vscodeThemeText =
    variant: s:
    let
      token = scope: foreground: {
        inherit scope;
        settings = { inherit foreground; };
      };
      terminal = lib.listToAttrs (
        lib.zipListsWith (n: c: lib.nameValuePair "terminal.ansi${n}" c) vscodeAnsiNames (tty16FromSlots s)
      );
    in
    jsonText {
      name = "Marchyo";
      type = variant;
      semanticHighlighting = true;
      colors = {
        "foreground" = s.base05;
        "focusBorder" = s.base0D;
        "descriptionForeground" = s.base04;
        "errorForeground" = s.base08;
        "selection.background" = s.base02;
        "editor.background" = s.base00;
        "editor.foreground" = s.base05;
        "editor.selectionBackground" = s.base02;
        "editor.lineHighlightBackground" = s.base01;
        "editor.findMatchBackground" = s.base02;
        "editorCursor.foreground" = s.base05;
        "editorLineNumber.foreground" = s.base03;
        "editorLineNumber.activeForeground" = s.base05;
        "editorIndentGuide.background1" = s.base01;
        "editorWhitespace.foreground" = s.base03;
        "editorGroupHeader.tabsBackground" = s.base01;
        "editorWidget.background" = s.base01;
        "activityBar.background" = s.base01;
        "activityBar.foreground" = s.base05;
        "activityBar.inactiveForeground" = s.base04;
        "activityBarBadge.background" = s.base0D;
        "activityBarBadge.foreground" = s.base00;
        "sideBar.background" = s.base01;
        "sideBar.foreground" = s.base05;
        "sideBarSectionHeader.background" = s.base01;
        "statusBar.background" = s.base01;
        "statusBar.foreground" = s.base05;
        "statusBar.noFolderBackground" = s.base01;
        "titleBar.activeBackground" = s.base01;
        "titleBar.activeForeground" = s.base05;
        "titleBar.inactiveBackground" = s.base00;
        "tab.activeBackground" = s.base00;
        "tab.activeForeground" = s.base05;
        "tab.inactiveBackground" = s.base01;
        "tab.inactiveForeground" = s.base04;
        "tab.border" = s.base00;
        "panel.background" = s.base00;
        "panel.border" = s.base03;
        "panelTitle.activeForeground" = s.base05;
        "input.background" = s.base01;
        "input.foreground" = s.base05;
        "input.border" = s.base03;
        "button.background" = s.base0D;
        "button.foreground" = s.base00;
        "dropdown.background" = s.base01;
        "dropdown.foreground" = s.base05;
        "list.activeSelectionBackground" = s.base02;
        "list.activeSelectionForeground" = s.base05;
        "list.hoverBackground" = s.base01;
        "list.highlightForeground" = s.base0D;
        "textLink.foreground" = s.base0D;
        "badge.background" = s.base0D;
        "badge.foreground" = s.base00;
        "terminal.background" = s.base00;
        "terminal.foreground" = s.base05;
        "terminal.selectionBackground" = s.base02;
        "terminalCursor.foreground" = s.base05;
      }
      // terminal;
      tokenColors = [
        (token [ "comment" "punctuation.definition.comment" ] s.base03)
        (token [ "string" "constant.other.symbol" ] s.base0B)
        (token [ "constant.numeric" "constant.language" "constant" ] s.base09)
        (token [ "keyword" "storage.type" "storage.modifier" ] s.base0E)
        (token [ "keyword.operator" "punctuation" ] s.base05)
        (token [ "entity.name.function" "support.function" ] s.base0D)
        (token [ "entity.name.type" "entity.name.class" "support.type" "support.class" ] s.base0A)
        (token [ "variable" "variable.parameter" "entity.name.tag" "invalid" ] s.base08)
        (token [ "entity.other.attribute-name" ] s.base09)
      ];
    };

  # CSS snippet: Obsidian loads it from <vault>/.obsidian/snippets/.
  obsidianCssText = s: ''
    .theme-dark,
    .theme-light {
      --background-primary: ${s.base00};
      --background-primary-alt: ${s.base01};
      --background-secondary: ${s.base01};
      --background-secondary-alt: ${s.base00};
      --background-modifier-border: ${s.base03};
      --text-normal: ${s.base05};
      --text-muted: ${s.base04};
      --text-faint: ${s.base03};
      --text-selection: ${s.base02};
      --text-link: ${s.base0D};
      --text-accent: ${s.base0D};
      --text-accent-hover: ${s.base0D};
      --interactive-accent: ${s.base0D};
      --interactive-accent-hover: ${s.base0D};
      --text-error: ${s.base08};
      --text-success: ${s.base0B};
      --code-normal: ${s.base0C};
      --tag-color: ${s.base0C};
      --text-title-h1: ${s.base08};
      --text-title-h2: ${s.base0B};
      --text-title-h3: ${s.base0A};
      --text-title-h4: ${s.base0D};
      --text-title-h5: ${s.base0E};
      --text-title-h6: ${s.base0E};
      --graph-line: ${s.base03};
      --graph-node: ${s.base0D};
    }
  '';

  # Status line, messages, pane borders and pane background. Sourced from the
  # tmux config (build-time copy first, current-theme copy after it).
  tmuxConfText = s: ''
    set -g status-style "fg=${s.base05},bg=${s.base01}"
    set -g message-style "fg=${s.base05},bg=${s.base02}"
    set -g message-command-style "fg=${s.base05},bg=${s.base02}"
    set -g mode-style "fg=${s.base05},bg=${s.base02}"
    set -g pane-border-style "fg=${s.base03}"
    set -g pane-active-border-style "fg=${s.base0D}"
    set -g window-style "fg=${s.base05},bg=${s.base00}"
    set -g window-active-style "fg=${s.base05},bg=${s.base00}"
    set -g window-status-style "fg=${s.base04},bg=${s.base01}"
    set -g window-status-current-style "fg=${s.base00},bg=${s.base0D},bold"
    set -g window-status-activity-style "fg=${s.base0A},bg=${s.base01}"
    set -g window-status-bell-style "fg=${s.base08},bg=${s.base01}"
    set -g clock-mode-colour "${s.base0D}"
    set -g display-panes-colour "${s.base04}"
    set -g display-panes-active-colour "${s.base0D}"
  '';

  # Slack colour preferences (mode, sidebar background, accent, ok, error),
  # applied by the opt-in launcher (modules/nixos/slack.nix).
  slackJsonText =
    variant: s:
    jsonText {
      mode = variant;
      background = s.base00;
      accent = s.base0D;
      green = s.base0B;
      red = s.base08;
    };

  # fcitx5 classicui theme; the svg glyphs are linked in beside it.
  fcitx5ThemeText = s: ''
    [Metadata]
    Name=Marchyo
    Version=1
    Author=Marchyo
    Description=Generated from the current Marchyo theme
    ScaleWithDPI=True

    [InputPanel]
    NormalColor=${s.base05}
    HighlightCandidateColor=${s.base00}
    HighlightColor=${s.base00}
    HighlightBackgroundColor=${s.base0D}
    PageButtonAlignment=Last Candidate

    [InputPanel/TextMargin]
    Left=12
    Right=12
    Top=8
    Bottom=8

    [InputPanel/ContentMargin]
    Left=6
    Right=6
    Top=6
    Bottom=6

    [InputPanel/Background]
    Color=${s.base00}
    BorderColor=${s.base02}
    BorderWidth=2

    [InputPanel/Background/Margin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [InputPanel/Highlight]
    Color=${s.base0D}

    [InputPanel/Highlight/Margin]
    Left=8
    Right=8
    Top=5
    Bottom=5

    [InputPanel/PrevPage]
    Image=prev.svg

    [InputPanel/PrevPage/ClickMargin]
    Left=6
    Right=6
    Top=5
    Bottom=5

    [InputPanel/NextPage]
    Image=next.svg

    [InputPanel/NextPage/ClickMargin]
    Left=6
    Right=6
    Top=5
    Bottom=5

    [Menu]
    NormalColor=${s.base05}
    HighlightCandidateColor=${s.base00}

    [Menu/Background]
    Color=${s.base00}
    BorderColor=${s.base02}
    BorderWidth=2

    [Menu/Background/Margin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [Menu/ContentMargin]
    Left=6
    Right=6
    Top=6
    Bottom=6

    [Menu/CheckBox]
    Image=radio.svg

    [Menu/SubMenu]
    Image=arrow.svg

    [Menu/Highlight]
    Color=${s.base0D}

    [Menu/Highlight/Margin]
    Left=8
    Right=8
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=${s.base03}

    [Menu/TextMargin]
    Left=12
    Right=12
    Top=8
    Bottom=8
  '';

  # herdr and herdr-app custom theme (the app's palette format).
  herdrJsonText =
    s:
    let
      ansi = tty16FromSlots s;
    in
    jsonText {
      background = s.base00;
      foreground = s.base05;
      selection = s.base02;
      cursor = builtins.elemAt ansi 15;
      inherit ansi;
      colors = {
        accent = s.base0D;
        accent_foreground = s.base00;
        solid = s.base0D;
        solid_foreground = s.base00;
      };
    };

  # File name -> text for every application surface of one theme.
  appSurfaceTexts = variant: s: {
    "vscode-theme.json" = vscodeThemeText variant s;
    "obsidian.css" = obsidianCssText s;
    "tmux.conf" = tmuxConfText s;
    "slack.json" = slackJsonText variant s;
    "fcitx5-theme.conf" = fcitx5ThemeText s;
    "herdr.json" = herdrJsonText s;
  };

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
      surfaces = appSurfaceTexts "dark" base16;
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
    jsonText
    vscodeThemeText
    obsidianCssText
    tmuxConfText
    slackJsonText
    fcitx5ThemeText
    herdrJsonText
    appSurfaceTexts
    parityExpected
    ;
}
