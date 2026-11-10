# Renders the bind table (lib/keybinds.nix) into Hyprland binds and tags
# terminal windows for the universal clipboard binds. Feature modules
# contribute only what the table cannot compute itself: store-path commands
# (`marchyo.keybinds.commands`) and keyed web apps (`marchyo.keybinds.webapps`).
{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkOption types;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  marchyoCfg = osConfig.marchyo;
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && marchyoCfg.desktop.enable;
  cfg = config.marchyo.keybinds;

  cliEnabled = marchyoCfg.cli.enable;
  shellEnabled = marchyoCfg.shell.enable;

  dictationCfg = marchyoCfg.dictation;
  dictationEnabled = dictationCfg.enable;
  dictationBackend = dictationCfg.backend;

  emacsCfg = marchyoCfg.emacs;
  emacsEnabled = emacsCfg.enable;
  emacsFeature = name: emacsEnabled && emacsCfg.${name}.enable;

  ctx = {
    # The store path when the CLI is not installed system-wide, so the shell
    # binds never depend on marchyo.cli.enable.
    cli = if cliEnabled then "marchyo" else lib.getExe pkgs.marchyo-cli;
    shell = shellEnabled;
    launcher = marchyoCfg.launcher.enable;
    perMonitor = marchyoCfg.workspaces.perMonitor;
    kbdBacklight = marchyoCfg.keyboard.backlight.enable;
    dictation = {
      enabled = dictationEnabled;
      inherit (dictationCfg) toggleKey;
      # Push-to-talk (F9) is voxtype's own evdev hotkey, not a Hyprland bind.
      statusWindow = dictationEnabled && dictationBackend == "voxtype" && dictationCfg.statusWindow;
    };
    cheatsheet = config.marchyo.keybindingsHelp.enable;
    menus = marchyoCfg.menus.enable;
    screenshot = {
      inherit (config.marchyo.screenshot) enable;
      annotation = config.marchyo.screenshot.enableAnnotation;
      ocr = config.marchyo.screenshot.enableOcr;
    };
    reminders = marchyoCfg.reminders.enable;
    utilities = marchyoCfg.utilities.enable;
    emacs = {
      enable = emacsEnabled;
      windmove = emacsFeature "windmove";
      scratchpad = emacsFeature "scratchpad";
      everywhere = emacsFeature "everywhere";
      orgProtocol = emacsFeature "orgProtocol";
    };
    inherit (cfg) commands webapps;
  };

  table = import ../../lib/keybinds.nix { inherit lib; } ctx;
  selected = lib.filter (e: e.when or true) table;

  # A web app key on a chord marchyo already binds is dropped with a warning,
  # so the marchyo bind keeps working.
  isWebapp = e: e.group == "Web apps";
  marchyoChords = map (e: hlua.normalizeKeys e.combo) (lib.filter (e: !(isWebapp e)) selected);
  clashes = e: isWebapp e && lib.elem (hlua.normalizeKeys e.combo) marchyoChords;
  active = lib.filter (e: !(clashes e)) selected;
  clashWarnings = map (
    e:
    "marchyo.webapps: the key of web app '${e.description}' (${e.combo}) is a marchyo bind, so the web app gets no bind. Pick another key (see marchyo.webapps.apps.*.key)."
  ) (lib.filter clashes selected);

  # Windows that get Ctrl+Shift+C/V from Super+C/V: the configured terminal
  # (the `terminal` Lua local) plus the terminals marchyo knows by class.
  terminalSetting = config.wayland.windowManager.hyprland.settings.terminal._var or "ghostty";
  terminalName = baseNameOf (builtins.head (lib.splitString " " terminalSetting));
  knownTerminalClasses = [
    "com.mitchellh.ghostty"
    "ghostty"
    "kitty"
    "Alacritty"
    "alacritty"
    "foot"
    "footclient"
    "org.wezfurlong.wezterm"
    "wezterm"
    "org.kde.konsole"
    "konsole"
    "org.gnome.Ptyxis"
    "org.gnome.Console"
    "xterm"
    "XTerm"
  ];
  terminalClassRegex = "^(${
    lib.concatMapStringsSep "|" lib.escapeRegex (lib.unique (knownTerminalClasses ++ [ terminalName ]))
  }|org\\.omarchy\\..*)$";

  render =
    e:
    let
      opts = (e.opts or { }) // lib.optionalAttrs (!(e.hidden or false)) { inherit (e) description; };
    in
    if opts == { } then hlua.bind e.combo e.action else hlua.bindOpts e.combo e.action opts;

  # The cheat sheet (`marchyo keybindings`) reads this file, so it lists the
  # table in table order with its groups.
  # Keycodes 10..19 are the number row; the sheet shows their digits.
  keyLabel = lib.replaceStrings (map (n: "code:${toString (n + 9)}") (lib.range 1 10)) (
    map (n: toString (lib.mod n 10)) (lib.range 1 10)
  );
  # `dispatch` is the action as a `hyprctl dispatch` argument when it is a plain
  # dispatcher expression; the launcher's keys mode runs it on Enter. Function
  # actions (cycleLayout, universal copy) have none and stay listed only.
  dispatchOf =
    e:
    let
      a = e.action;
      expr = a.expr or "";
      # The generated config binds terminal, browser and the like as Lua locals,
      # which `hyprctl dispatch` cannot see.
      usesLocals = builtins.match ".*exec_cmd\\([a-zA-Z].*" expr != null;
    in
    if
      builtins.isAttrs a && (a._type or "") == "lua-inline" && lib.hasPrefix "hl.dsp." expr && !usesLocals
    then
      builtins.unsafeDiscardStringContext expr
    else
      null;
  sheet = map (e: {
    inherit (e) description group;
    combo = keyLabel e.combo;
    dispatch = dispatchOf e;
  }) (lib.filter (e: !(e.hidden or false)) active);
in
{
  options.marchyo.keybinds = {
    commands = mkOption {
      type = types.attrsOf types.str;
      default = { };
      internal = true;
      description = "Commands for table entries whose program a feature module builds.";
    };
    webapps = mkOption {
      type = types.listOf (types.attrsOf types.str);
      default = [ ];
      internal = true;
      description = "Keyed web apps: `{ combo, name, command }` each.";
    };
    table = mkOption {
      type = types.listOf types.raw;
      readOnly = true;
      internal = true;
      description = "The bind table entries in effect for this configuration.";
    };
    terminalClassRegex = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      description = "Window classes tagged `terminal` for the universal clipboard.";
    };
  };

  config = lib.mkMerge [
    {
      marchyo.keybinds = {
        table = if desktopEnabled then active else [ ];
        inherit terminalClassRegex;
      };
    }
    (lib.mkIf desktopEnabled {
      warnings = clashWarnings;
      wayland.windowManager.hyprland.settings.bind = map render active;
      wayland.windowManager.hyprland.settings.window_rule = [
        {
          match.class = terminalClassRegex;
          tag = "+terminal";
        }
      ];
      xdg.configFile."marchyo/keybindings.json".text = builtins.toJSON sheet;
    })
  ];
}
