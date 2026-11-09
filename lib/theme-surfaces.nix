# Terminal and editor theme surfaces, all from base16 slots
# (modules/home/theme-runtime.nix emits them into every theme dir).
# Pure string work, IFD-free. `gen` is lib/theme-generators.nix.
#
# `templates` applies the same generators to `{{token:<name>}}` placeholders,
# which is what `marchyo theme generate` fills from a matugen palette (foot
# wants bare RRGGBB, so its template uses `{{bare:<name>}}`).
{ lib, gen }:
let
  inherit (gen) tty16FromSlots;
  noHash = lib.removePrefix "#";

  # Slot -> the semantic token whose colour a scheme dir gives it (base07 is
  # text-heading, as in jylhis-palette.nix).
  slotTokens = {
    base00 = "bg";
    base01 = "bg-subtle";
    base02 = "selection-bg";
    base03 = "text-faint";
    base04 = "text-muted";
    base05 = "text";
    base06 = "text-heading";
    base07 = "text-heading";
    base08 = "status-err";
    base09 = "syn-number";
    base0A = "status-warn";
    base0B = "syn-string";
    base0C = "syn-type";
    base0D = "syn-function";
    base0E = "syn-keyword";
    base0F = "syn-docstring";
  };
  templateSlots = lib.mapAttrs (_: t: "{{token:${t}}}") slotTokens;
  # base07 is left out of emitted tables: a scheme's own base07 has no token.
  slotNames = lib.filter (n: n != "base07") (lib.attrNames slotTokens);

  ansiNames = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];
  ansiPairs =
    s:
    let
      c = tty16FromSlots s;
    in
    lib.imap0 (i: name: {
      inherit i name;
      normal = builtins.elemAt c i;
      bright = builtins.elemAt c (i + 8);
    }) ansiNames;

  # btop theme (`theme[key]="#rrggbb"`), selected by `color_theme` in btop.conf.
  btopThemeText =
    s:
    let
      keys = {
        main_bg = s.base00;
        main_fg = s.base05;
        title = s.base05;
        hi_fg = s.base0D;
        selected_bg = s.base02;
        selected_fg = s.base06;
        inactive_fg = s.base03;
        graph_text = s.base04;
        meter_bg = s.base02;
        proc_misc = s.base0C;
        cpu_box = s.base0B;
        mem_box = s.base0A;
        net_box = s.base0E;
        proc_box = s.base0D;
        div_line = s.base03;
        temp_start = s.base0B;
        temp_mid = s.base0A;
        temp_end = s.base08;
        cpu_start = s.base0B;
        cpu_mid = s.base0A;
        cpu_end = s.base08;
        free_start = s.base0B;
        free_mid = s.base0B;
        free_end = s.base0C;
        cached_start = s.base0D;
        cached_mid = s.base0D;
        cached_end = s.base0C;
        available_start = s.base0A;
        available_mid = s.base0A;
        available_end = s.base09;
        used_start = s.base0E;
        used_mid = s.base09;
        used_end = s.base08;
        download_start = s.base0D;
        download_mid = s.base0C;
        download_end = s.base0B;
        upload_start = s.base0E;
        upload_mid = s.base09;
        upload_end = s.base08;
        process_start = s.base0B;
        process_mid = s.base0A;
        process_end = s.base08;
      };
    in
    lib.concatMapStrings (k: "theme[${k}]=${builtins.toJSON keys.${k}}\n") (lib.attrNames keys);

  # kitty colour block: `kitty @ set-colors` reads it as is and kitty.conf can
  # `include` it.
  kittyConfText =
    s:
    ''
      foreground ${s.base05}
      background ${s.base00}
      selection_foreground ${s.base05}
      selection_background ${s.base02}
      cursor ${s.base05}
      cursor_text_color ${s.base00}
      url_color ${s.base0D}
      active_border_color ${s.base0D}
      inactive_border_color ${s.base03}
      bell_border_color ${s.base0A}
      active_tab_foreground ${s.base00}
      active_tab_background ${s.base0D}
      inactive_tab_foreground ${s.base04}
      inactive_tab_background ${s.base01}
      tab_bar_background ${s.base00}
    ''
    + lib.concatImapStrings (i: c: "color${toString (i - 1)} ${c}\n") (tty16FromSlots s);

  # foot colours, bare RRGGBB. Both colour sections carry the palette so it
  # applies whichever scheme foot selects.
  footThemeText =
    s:
    let
      section =
        name:
        ''
          [${name}]
          foreground=${noHash s.base05}
          background=${noHash s.base00}
          selection-foreground=${noHash s.base05}
          selection-background=${noHash s.base02}
          cursor=${noHash s.base00} ${noHash s.base05}
          urls=${noHash s.base0D}
        ''
        + lib.concatMapStrings (
          e: "regular${toString e.i}=${noHash e.normal}\nbright${toString e.i}=${noHash e.bright}\n"
        ) (ansiPairs s);
    in
    section "colors-dark" + "\n" + section "colors-light";

  # alacritty colour tables, pulled in with `general.import`.
  alacrittyThemeText =
    s:
    let
      table =
        key: field:
        "[colors.${key}]\n"
        + lib.concatMapStrings (e: "${e.name} = ${builtins.toJSON e.${field}}\n") (ansiPairs s);
    in
    ''
      [colors.primary]
      background = "${s.base00}"
      foreground = "${s.base05}"

      [colors.cursor]
      text = "${s.base00}"
      cursor = "${s.base05}"

      [colors.selection]
      text = "${s.base05}"
      background = "${s.base02}"

    ''
    + table "normal" "normal"
    + "\n"
    + table "bright" "bright";

  # Helix theme (`theme = "marchyo"`): scopes name palette slots.
  helixScopes =
    let
      fgOnly = fg: { inherit fg; };
      pair = fg: bg: { inherit fg bg; };
      curl = color: {
        underline = {
          inherit color;
          style = "curl";
        };
      };
    in
    {
      "ui.background".bg = "base00";
      "ui.text" = fgOnly "base05";
      "ui.text.focus" = pair "base06" "base02";
      "ui.cursor" = pair "base00" "base05";
      "ui.cursor.primary" = pair "base00" "base05";
      "ui.cursor.match" = {
        fg = "base0A";
        modifiers = [ "bold" ];
      };
      "ui.selection".bg = "base02";
      "ui.selection.primary".bg = "base02";
      "ui.linenr" = fgOnly "base03";
      "ui.linenr.selected" = fgOnly "base05";
      "ui.cursorline.primary".bg = "base01";
      "ui.statusline" = pair "base05" "base01";
      "ui.statusline.inactive" = pair "base04" "base01";
      "ui.statusline.normal" = pair "base00" "base0D";
      "ui.statusline.insert" = pair "base00" "base0B";
      "ui.statusline.select" = pair "base00" "base0E";
      "ui.popup" = pair "base05" "base01";
      "ui.window" = fgOnly "base03";
      "ui.help" = pair "base05" "base01";
      "ui.menu" = pair "base05" "base01";
      "ui.menu.selected" = pair "base06" "base02";
      "ui.virtual.whitespace" = fgOnly "base03";
      "ui.virtual.ruler".bg = "base01";
      "ui.virtual.indent-guide" = fgOnly "base02";
      "ui.virtual.inlay-hint" = fgOnly "base03";
      "ui.bufferline" = pair "base04" "base01";
      "ui.bufferline.active" = pair "base05" "base00";
      attribute = "base09";
      comment = {
        fg = "base03";
        modifiers = [ "italic" ];
      };
      constant = "base09";
      "constant.character.escape" = "base0C";
      "constant.numeric" = "base09";
      constructor = "base0D";
      function = "base0D";
      "function.macro" = "base0E";
      keyword = "base0E";
      "keyword.directive" = "base0E";
      label = "base0E";
      namespace = "base0A";
      operator = "base05";
      punctuation = "base05";
      special = "base0D";
      string = "base0B";
      "string.regexp" = "base0C";
      "string.special" = "base0F";
      tag = "base08";
      type = "base0A";
      "type.builtin" = "base0C";
      variable = "base08";
      "variable.parameter" = "base08";
      "variable.other.member" = "base0D";
      "markup.heading" = {
        fg = "base0D";
        modifiers = [ "bold" ];
      };
      "markup.list" = "base08";
      "markup.bold" = {
        fg = "base0A";
        modifiers = [ "bold" ];
      };
      "markup.italic" = {
        fg = "base0E";
        modifiers = [ "italic" ];
      };
      "markup.link.url" = {
        fg = "base09";
        modifiers = [ "underlined" ];
      };
      "markup.link.text" = "base08";
      "markup.quote" = "base0C";
      "markup.raw" = "base0B";
      "diff.plus" = "base0B";
      "diff.minus" = "base08";
      "diff.delta" = "base0A";
      error = "base08";
      warning = "base0A";
      info = "base0D";
      hint = "base0C";
      "diagnostic.error" = curl "base08";
      "diagnostic.warning" = curl "base0A";
      "diagnostic.info" = curl "base0D";
      "diagnostic.hint" = curl "base0C";
    };

  helixThemeText =
    s:
    let
      inline =
        v:
        if builtins.isString v then
          builtins.toJSON v
        else if builtins.isList v then
          "[" + lib.concatMapStringsSep ", " builtins.toJSON v + "]"
        else
          "{ " + lib.concatMapStringsSep ", " (k: "${k} = ${inline v.${k}}") (lib.attrNames v) + " }";
    in
    lib.concatMapStrings (k: "${builtins.toJSON k} = ${inline helixScopes.${k}}\n") (
      lib.attrNames helixScopes
    )
    + "\n[palette]\n"
    + lib.concatMapStrings (k: "${k} = ${builtins.toJSON s.${k}}\n") slotNames;

  # Neovim colorscheme (colors/marchyo.lua). `background` follows the luminance
  # of base00, so the file needs no polarity input.
  nvimGroups = {
    Normal = "{ fg = c.base05, bg = c.base00 }";
    NormalFloat = "{ fg = c.base05, bg = c.base01 }";
    FloatBorder = "{ fg = c.base03, bg = c.base01 }";
    Cursor = "{ fg = c.base00, bg = c.base05 }";
    CursorLine = "{ bg = c.base01 }";
    CursorLineNr = "{ fg = c.base05, bg = c.base01 }";
    LineNr = "{ fg = c.base03 }";
    SignColumn = "{ fg = c.base03, bg = c.base00 }";
    ColorColumn = "{ bg = c.base01 }";
    Visual = "{ bg = c.base02 }";
    Search = "{ fg = c.base00, bg = c.base0A }";
    IncSearch = "{ fg = c.base00, bg = c.base09 }";
    MatchParen = "{ fg = c.base0A, bold = true }";
    StatusLine = "{ fg = c.base05, bg = c.base01 }";
    StatusLineNC = "{ fg = c.base04, bg = c.base01 }";
    TabLine = "{ fg = c.base04, bg = c.base01 }";
    TabLineSel = "{ fg = c.base00, bg = c.base0D }";
    TabLineFill = "{ bg = c.base01 }";
    VertSplit = "{ fg = c.base03 }";
    WinSeparator = "{ fg = c.base03 }";
    Pmenu = "{ fg = c.base05, bg = c.base01 }";
    PmenuSel = "{ fg = c.base06, bg = c.base02 }";
    PmenuSbar = "{ bg = c.base02 }";
    PmenuThumb = "{ bg = c.base04 }";
    Folded = "{ fg = c.base04, bg = c.base01 }";
    NonText = "{ fg = c.base03 }";
    Whitespace = "{ fg = c.base03 }";
    EndOfBuffer = "{ fg = c.base00 }";
    Directory = "{ fg = c.base0D }";
    Title = "{ fg = c.base0D, bold = true }";
    ErrorMsg = "{ fg = c.base08 }";
    WarningMsg = "{ fg = c.base0A }";
    MoreMsg = "{ fg = c.base0B }";
    Question = "{ fg = c.base0D }";
    Comment = "{ fg = c.base03, italic = true }";
    Constant = "{ fg = c.base09 }";
    String = "{ fg = c.base0B }";
    Character = "{ fg = c.base08 }";
    Number = "{ fg = c.base09 }";
    Boolean = "{ fg = c.base09 }";
    Float = "{ fg = c.base09 }";
    Identifier = "{ fg = c.base08 }";
    Function = "{ fg = c.base0D }";
    Statement = "{ fg = c.base0E }";
    Conditional = "{ fg = c.base0E }";
    Repeat = "{ fg = c.base0E }";
    Label = "{ fg = c.base0A }";
    Operator = "{ fg = c.base05 }";
    Keyword = "{ fg = c.base0E }";
    Exception = "{ fg = c.base08 }";
    PreProc = "{ fg = c.base0A }";
    Include = "{ fg = c.base0D }";
    Define = "{ fg = c.base0E }";
    Macro = "{ fg = c.base08 }";
    Type = "{ fg = c.base0A }";
    StorageClass = "{ fg = c.base0A }";
    Structure = "{ fg = c.base0E }";
    Special = "{ fg = c.base0C }";
    SpecialChar = "{ fg = c.base0F }";
    Delimiter = "{ fg = c.base0F }";
    Underlined = "{ fg = c.base0D, underline = true }";
    Error = "{ fg = c.base00, bg = c.base08 }";
    Todo = "{ fg = c.base0A, bg = c.base01, bold = true }";
    DiffAdd = "{ fg = c.base0B, bg = c.base01 }";
    DiffChange = "{ fg = c.base0A, bg = c.base01 }";
    DiffDelete = "{ fg = c.base08, bg = c.base01 }";
    DiffText = "{ fg = c.base0D, bg = c.base02 }";
    DiagnosticError = "{ fg = c.base08 }";
    DiagnosticWarn = "{ fg = c.base0A }";
    DiagnosticInfo = "{ fg = c.base0D }";
    DiagnosticHint = "{ fg = c.base0C }";
    DiagnosticUnderlineError = "{ undercurl = true, sp = c.base08 }";
    DiagnosticUnderlineWarn = "{ undercurl = true, sp = c.base0A }";
    DiagnosticUnderlineInfo = "{ undercurl = true, sp = c.base0D }";
    DiagnosticUnderlineHint = "{ undercurl = true, sp = c.base0C }";
    SpellBad = "{ undercurl = true, sp = c.base08 }";
    SpellCap = "{ undercurl = true, sp = c.base0A }";
    "@variable" = "{ fg = c.base05 }";
    "@variable.builtin" = "{ fg = c.base09 }";
    "@variable.parameter" = "{ fg = c.base08 }";
    "@property" = "{ fg = c.base0D }";
    "@function.builtin" = "{ fg = c.base0C }";
    "@constructor" = "{ fg = c.base0D }";
    "@tag" = "{ fg = c.base08 }";
    "@tag.attribute" = "{ fg = c.base09 }";
    "@markup.heading" = "{ fg = c.base0D, bold = true }";
    "@markup.link.url" = "{ fg = c.base09, underline = true }";
    "@markup.raw" = "{ fg = c.base0B }";
  };

  nvimThemeText =
    s:
    ''
      -- Generated by marchyo from the current theme.
      vim.cmd("highlight clear")
      if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
      end
      vim.g.colors_name = "marchyo"

      local c = {
    ''
    + lib.concatMapStrings (k: "  ${k} = ${builtins.toJSON s.${k}},\n") slotNames
    + ''
      }

      local function luminance(hex)
        local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
        return 0.2126 * tonumber(r, 16) + 0.7152 * tonumber(g, 16) + 0.0722 * tonumber(b, 16)
      end
      vim.o.background = luminance(c.base00) < 128 and "dark" or "light"
      vim.o.termguicolors = true

      local groups = {
    ''
    + lib.concatMapStrings (k: "  [${builtins.toJSON k}] = ${nvimGroups.${k}},\n") (
      lib.attrNames nvimGroups
    )
    + ''
      }
      for name, spec in pairs(groups) do
        vim.api.nvim_set_hl(0, name, spec)
      end

      local ansi = {
    ''
    + lib.concatMapStrings (c: "  ${builtins.toJSON c},\n") (tty16FromSlots s)
    + ''
      }
      for i, colour in ipairs(ansi) do
        vim.g["terminal_color_" .. (i - 1)] = colour
      end
    '';

  # Emacs theme: `(load-file ...)` defines and enables the `marchyo` theme.
  emacsFaces = {
    default = ":background ,bg :foreground ,fg";
    cursor = ":background ,fg";
    region = ":background ,sel :extend t";
    secondary-selection = ":background ,bg1";
    highlight = ":background ,sel";
    hl-line = ":background ,bg1 :extend t";
    fringe = ":background ,bg :foreground ,faint";
    line-number = ":background ,bg :foreground ,faint";
    line-number-current-line = ":background ,bg1 :foreground ,fg";
    mode-line = ":background ,bg1 :foreground ,fg :box nil";
    mode-line-inactive = ":background ,bg1 :foreground ,muted :box nil";
    header-line = ":background ,bg1 :foreground ,fg";
    vertical-border = ":foreground ,faint";
    window-divider = ":foreground ,faint";
    minibuffer-prompt = ":foreground ,blue :weight bold";
    link = ":foreground ,blue :underline t";
    link-visited = ":foreground ,magenta :underline t";
    shadow = ":foreground ,faint";
    error = ":foreground ,red";
    warning = ":foreground ,yellow";
    success = ":foreground ,green";
    isearch = ":background ,yellow :foreground ,bg";
    lazy-highlight = ":background ,sel :foreground ,fg";
    show-paren-match = ":background ,sel :foreground ,yellow :weight bold";
    font-lock-comment-face = ":foreground ,faint :slant italic";
    font-lock-doc-face = ":foreground ,doc";
    font-lock-string-face = ":foreground ,green";
    font-lock-keyword-face = ":foreground ,magenta";
    font-lock-builtin-face = ":foreground ,cyan";
    font-lock-function-name-face = ":foreground ,blue";
    font-lock-variable-name-face = ":foreground ,red";
    font-lock-type-face = ":foreground ,yellow";
    font-lock-constant-face = ":foreground ,orange";
    font-lock-warning-face = ":foreground ,red :weight bold";
    font-lock-preprocessor-face = ":foreground ,yellow";
    tab-bar = ":background ,bg1 :foreground ,muted";
    tab-bar-tab = ":background ,bg :foreground ,fg";
    tab-bar-tab-inactive = ":background ,bg1 :foreground ,muted";
  };

  emacsThemeText =
    s:
    let
      q = builtins.toJSON;
      colours = {
        bg = s.base00;
        bg1 = s.base01;
        sel = s.base02;
        faint = s.base03;
        muted = s.base04;
        fg = s.base05;
        red = s.base08;
        orange = s.base09;
        yellow = s.base0A;
        green = s.base0B;
        cyan = s.base0C;
        blue = s.base0D;
        magenta = s.base0E;
        doc = s.base0F;
      };
      names = lib.attrNames colours;
      ansi = ansiPairs s;
      ansiFace =
        e:
        "   `(ansi-color-${e.name} ((t (:foreground ${q e.normal} :background ${q e.normal}))))\n"
        + "   `(ansi-color-bright-${e.name} ((t (:foreground ${q e.bright} :background ${q e.bright}))))\n";
    in
    ''
      ;;; marchyo-theme.el --- Generated by marchyo from the current theme  -*- lexical-binding: t; -*-

      (deftheme marchyo "Colours of the current marchyo theme.")

      (let* (${lib.concatMapStringsSep "\n       " (n: "(${n} ${q colours.${n}})") names})
        (custom-theme-set-faces
         'marchyo
    ''
    + lib.concatMapStrings (k: "   `(${k} ((t (${emacsFaces.${k}}))))\n") (lib.attrNames emacsFaces)
    + lib.concatMapStrings ansiFace ansi
    + ''
        )
        (custom-theme-set-variables
         'marchyo
         '(ansi-color-names-vector
           [${lib.concatMapStringsSep " " (e: q e.normal) ansi}])))

      (provide-theme 'marchyo)
      (enable-theme 'marchyo)

      ;;; marchyo-theme.el ends here
    '';

  texts = s: {
    "btop.theme" = btopThemeText s;
    "kitty.conf" = kittyConfText s;
    "foot-theme.ini" = footThemeText s;
    "alacritty-theme.toml" = alacrittyThemeText s;
    "helix-theme.toml" = helixThemeText s;
    "nvim-theme.lua" = nvimThemeText s;
    "emacs-theme.el" = emacsThemeText s;
  };

  templates =
    let
      t = texts templateSlots;
    in
    t
    // {
      "foot-theme.ini" = builtins.replaceStrings [ "{{token:" ] [ "{{bare:" ] t."foot-theme.ini";
    };
in
{
  inherit
    texts
    templates
    templateSlots
    ;
}
