{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let

  # Inert on darwin and on headless Linux, so consumers never need disabledModules.
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # The marchyo CLI persists ephemeral runtime overrides (theme/toggle
  # changes made without --apply); restore them at session start.
  cliEnabled = (osConfig.marchyo or { }).cli.enable or false;

  hasNvidia = builtins.elem "nvidia" (osConfig.marchyo.graphics.vendors or [ ]);
  isPrimeOffload =
    (osConfig.marchyo.graphics.prime.enable or false)
    && (osConfig.marchyo.graphics.prime.mode or "") == "offload";

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };

  wallpaperCfg = ((osConfig.marchyo or { }).theme or { }).wallpaper or { };
  wallpaperEnabled = wallpaperCfg.enable or true;
  wallpaperPackage = wallpaperCfg.package or pkgs.marchyo-wallpapers;
  wallpaperFile = "${wallpaperPackage}/share/marchyo/wallpapers/jylhis-grid-${
    if isDark then "dark" else "light"
  }.png";

  setWallpaper = pkgs.writeShellScript "marchyo-set-wallpaper" ''
    for _ in 1 2 3 4 5; do
      if ${pkgs.awww}/bin/awww img "${wallpaperFile}" --transition-type none; then
        exit 0
      fi
      sleep 0.2
    done
    exit 0
  '';

  # Hyprland color syntax: "#RRGGBB" to rgb()/rgba().
  rgb = h: "rgb(${lib.removePrefix "#" h})";
  rgba = h: a: "rgba(${lib.removePrefix "#" h}${a})";

  marchyoDefaults = (osConfig.marchyo or { }).defaults or { };

  # Declarative monitor layout (marchyo.monitors) rendered into the Hyprland
  # Lua `monitor` table list. Empty (the default) keeps the catch-all that
  # auto-detects every output at its preferred mode, position, and scale 1.
  monitorCfg = (osConfig.marchyo or { }).monitors or [ ];
  renderMonitor =
    m:
    if !m.enable then
      # Hyprland disables an output with the `disabled` table field; "disable"
      # is not a valid value for `mode`, and hl.monitor takes only a table.
      {
        inherit (m) output;
        disabled = true;
      }
    else
      {
        inherit (m)
          output
          mode
          position
          scale
          ;
      }
      // lib.optionalAttrs (m.transform != 0) { inherit (m) transform; }
      // lib.optionalAttrs (m.vrr != null) { inherit (m) vrr; }
      // m.extraSettings;
  monitorList =
    if monitorCfg == [ ] then
      [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
          vrr = 1;
        }
      ]
    else
      map renderMonitor monitorCfg;

  dictationEnabled = ((osConfig.marchyo or { }).dictation or { }).enable or false;
  dictationToggleKey = ((osConfig.marchyo or { }).dictation or { }).toggleKey or "SUPER + CTRL + X";
  dictationStatusWindow =
    dictationEnabled && (((osConfig.marchyo or { }).dictation or { }).statusWindow or true);

  # The unified shell adds keybind summons for its panels via `marchyo shell`
  # (see the panel binds below); only wire them when the shell owns the desktop.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;

  # `marchyo` verbs for the shell-side binds. The store path when the CLI is
  # not installed system-wide, so the shell binds never depend on
  # marchyo.cli.enable.
  marchyoCli = if cliEnabled then "marchyo" else lib.getExe pkgs.marchyo-cli;
  shellVerb = args: "${marchyoCli} shell ${args}";

  # Glass surfaces: marchyo.theme.appearance.surfaceAlpha < 1 makes the shell's
  # cards translucent, which only reads as glass when the compositor blurs what
  # is behind them. Baked off (alpha 1) the blur effect stays disabled and no
  # layer rules are registered, reproducing the flat opaque look.
  surfaceAlpha = ((osConfig.marchyo or { }).theme.appearance or { }).surfaceAlpha or 1.0;
  glassEnabled = shellEnabled && surfaceAlpha < 1.0;

  # Gated on marchyo.launcher.enable so an opted-out host gets no dead binds.
  launcherEnabled = ((osConfig.marchyo or { }).launcher or { }).enable or false;

  # Lua-renderer helpers (bind/exec/env/onStart, see lib/hyprland-lua.nix).
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  inherit (hlua)
    mkLuaInline
    dsp
    exec
    execLua
    bind
    bindOpts
    bindd
    binddOpts
    env
    onStart
    ;

  browserHyprlandCommands = {
    brave = "brave --new-window";
    google-chrome = "google-chrome --new-window";
    firefox = "firefox --new-window";
    chromium = "chromium --new-window";
  };

  fileManagerHyprlandCommands = {
    nautilus = "nautilus --new-window";
    thunar = "thunar";
  };

  # The terminal command is resolved in Nix rather than through the Lua
  # `terminal` local, because the Home Manager renderer emits Lua locals in
  # alphabetical order: `music` sorts before `terminal`, so a local referring
  # to another local would resolve to nil.
  terminalCmd = "ghostty";

  musicHyprlandCommands = {
    # TUI clients launch in a floating terminal (Omarchy pattern, see window rule below)
    spotify-player = "${terminalCmd} --class=org.omarchy.spotify-player -e spotify-player";
    ncspot = "${terminalCmd} --class=org.omarchy.ncspot -e ncspot";
    spotify = "spotify";
  };

  # GUI editor launch commands, keyed by marchyo.defaults.editor.
  editorHyprlandCommands = {
    emacs = "emacsclient -c -a emacs";
    vscode = "code";
    vscodium = "codium";
    zed = "zed";
  };

  browserCmd =
    let
      b = marchyoDefaults.browser or "google-chrome";
    in
    if b == null then "xdg-open" else browserHyprlandCommands.${b};

  fileManagerCmd =
    let
      fm = marchyoDefaults.fileManager or "nautilus";
    in
    if fm == null then "xdg-open" else fileManagerHyprlandCommands.${fm};

  musicCmd =
    let
      m = marchyoDefaults.musicPlayer or "spotify-player";
    in
    if m == null then "xdg-open" else musicHyprlandCommands.${m};

  editorCmd =
    let
      e = marchyoDefaults.editor or "emacs";
    in
    if e == null then "xdg-open" else editorHyprlandCommands.${e};

in
{
  config = lib.mkIf desktopEnabled {

    gtk = {
      enable = true;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # UWSM manages systemd integration
      # `settings` below is written for the Lua renderer (hyprlang deprecated in 0.55).
      # mkDefault so a consumer needing hyprlang can pin it back.
      configType = lib.mkDefault "lua";
      settings = {

        # Default apps, emitted as Lua locals (`local terminal = "ghostty"`).
        # Override with e.g. `settings.terminal._var = "foot"`. Keep these flat:
        # a local must not reference another local (see terminalCmd above).

        notes = {
          _var = lib.mkDefault "obsidian";
        };
        browser = {
          _var = lib.mkDefault browserCmd;
        };
        fileManager = {
          _var = lib.mkDefault fileManagerCmd;
        };
        messenger = {
          _var = lib.mkDefault "signal-desktop";
        };
        music = {
          _var = lib.mkDefault musicCmd;
        };
        editor = {
          _var = lib.mkDefault editorCmd;
        };
        passwordManager = {
          _var = lib.mkDefault "1password";
        };
        terminal = {
          _var = lib.mkDefault terminalCmd;
        };

        # Everything that was a flat hyprlang section lives under `config`,
        # which renders as a single `hl.config({ ... })` call.
        config = {
          ecosystem.no_update_news = true;
          xwayland.force_zero_scaling = true;

          input = {
            kb_layout = lib.mkIf (
              (config.home ? keyboard) && (config.home.keyboard ? layout) && (config.home.keyboard.layout != null)
            ) (lib.mkDefault config.home.keyboard.layout);
            kb_options = lib.mkIf (
              (config.home ? keyboard)
              && (config.home.keyboard ? options)
              && (config.home.keyboard.options != null)
            ) (lib.mkDefault (lib.strings.join "," config.home.keyboard.options));
            kb_variant =
              lib.mkIf
                (
                  (config.home ? keyboard)
                  && (config.home.keyboard ? variant)
                  && (config.home.keyboard.variant != null)
                )
                (
                  lib.mkDefault (
                    if builtins.isList config.home.keyboard.variant then
                      lib.strings.join "," config.home.keyboard.variant
                    else
                      config.home.keyboard.variant
                  )
                );
            repeat_rate = 40;
            repeat_delay = 280;
            follow_mouse = 1;
            accel_profile = "flat";
            force_no_accel = true;
            sensitivity = 0.15;
            touchpad = {
              natural_scroll = false;
              disable_while_typing = true;
              # Lua spells this with an underscore; hyprlang used `tap-to-click`.
              tap_to_click = true;
              scroll_factor = 0.5;
            };

          };

          misc = {
            force_default_wallpaper = lib.mkDefault false;
            disable_hyprland_logo = lib.mkDefault true;
            disable_splash_rendering = true;
            focus_on_activate = true;
            background_color = lib.mkForce (rgb palette.hex.bg);
          };
          # tmux-style TUI grid: zero gaps, single-line pane borders.
          general = {
            gaps_in = 0;
            gaps_out = 0;
            border_size = 2;

            # Active pane accent, inactive border-strong (an ink token like text-faint
            # reads brighter than a border should on dark).
            col = {
              active_border = lib.mkForce (rgba palette.hex.accent "ff");
              inactive_border = lib.mkForce (rgba palette.hex."border-strong" "ff");
            };

            resize_on_border = true;
            hover_icon_on_border = true;
            allow_tearing = true;

            layout = "dwindle";
          };

          render = {
            direct_scanout = true;
          };

          cursor = {
            # Also keeps the cursor out of screenshots: every capture bind is a
            # keyboard bind, so the triggering key press hides it before grimblast runs.
            hide_on_key_press = true;
          }
          // lib.optionalAttrs hasNvidia {
            no_hardware_cursors = true;
          };

          # Flat TUI panes: sharp corners, no rounding/shadow. Blur is only on
          # when the shell's glass surfaces need it (surfaceAlpha < 1); app
          # windows never blur (the no_blur window rule below), so the effect
          # exists solely for the shell's layer surfaces.
          decoration = {
            rounding = 0;

            # No dimming; the active pane is identified by its accent border instead.
            dim_inactive = false;

            shadow = {
              enabled = false;
            };
          }
          // lib.optionalAttrs glassEnabled {
            blur = {
              enabled = true;
              size = 4;
              passes = 2;
            };
          };

          # Disabled for instant, terminal-multiplexer-style snapping.
          animations = {
            enabled = false;
          };

          dwindle = {
            preserve_split = true;
            force_split = 2;
          };

          master = {
            new_status = "master";
          };
        };

        monitor = lib.mkAfter monitorList;

        # Window rules. Order matters (rules are evaluated top to bottom).
        # See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
        window_rule = [
          # Ignore maximize requests from all apps.
          {
            match.class = ".*";
            suppress_event = "maximize";
          }

          # Browser types
          {
            match.class = "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)";
            tag = "+chromium-based-browser";
          }
          {
            match.class = "([fF]irefox|zen|librewolf)";
            tag = "+firefox-based-browser";
          }
          {
            match.tag = "chromium-based-browser";
            tag = "-default-opacity";
          }
          {
            match.tag = "firefox-based-browser";
            tag = "-default-opacity";
          }

          # Force chromium-based browsers into a tile to deal with --app bug
          {
            match.tag = "chromium-based-browser";
            tile = true;
          }

          # Video apps: remove chromium browser tag so they don't get opacity applied
          {
            match.class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)";
            tag = "-chromium-based-browser";
          }
          {
            match.class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)";
            tag = "-default-opacity";
          }

          # Floating windows
          {
            match.tag = "floating-window";
            float = true;
          }
          {
            match.tag = "floating-window";
            center = true;
          }
          {
            match.tag = "floating-window";
            size = [
              875
              600
            ];
          }

          {
            match.class = "(org.omarchy.bluetui|org.omarchy.nmtui|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.spotify-player|org.omarchy.ncspot|org.omarchy.voxtype|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)";
            tag = "+floating-window";
          }
          {
            match = {
              class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)";
              title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)";
            };
            tag = "+floating-window";
          }

          {
            match.class = "Screensaver";
            fullscreen = true;
          }

          # Float Steam windows.
          {
            match.class = "steam";
            float = true;
          }
          {
            match = {
              class = "steam";
              title = "Steam";
            };
            center = true;
          }
          {
            match.class = "steam.*";
            tag = "-default-opacity";
          }
          {
            match.class = "steam.*";
            opacity = "1 1";
          }
          {
            match = {
              class = "steam";
              title = "Steam";
            };
            size = [
              1100
              700
            ];
          }
          {
            match = {
              class = "steam";
              title = "Friends List";
            };
            size = [
              460
              800
            ];
          }

          # 1Password: keep out of screen shares, float it.
          {
            match.class = "^(1[p|P]assword)$";
            no_screen_share = true;
          }
          {
            match.class = "^(1[p|P]assword)$";
            tag = "+floating-window";
          }

          {
            match.class = ".*";
            opacity = "1.0 1.0";
          }

          # Picture-in-picture overlays
          {
            match.title = "(Picture.?in.?[Pp]icture)";
            tag = "+pip";
          }
          {
            match.tag = "pip";
            tag = "-default-opacity";
          }
          {
            match.tag = "pip";
            float = true;
          }
          {
            match.tag = "pip";
            pin = true;
          }
          {
            match.tag = "pip";
            size = [
              600
              338
            ];
          }
          {
            match.tag = "pip";
            keep_aspect_ratio = true;
          }
          {
            match.tag = "pip";
            border_size = 0;
          }
          {
            match.tag = "pip";
            opacity = "1 1";
          }
          {
            match.tag = "pip";
            move = [
              "(monitor_w-window_w-40)"
              "(monitor_h*0.04)"
            ];
          }

          # Glass shell surfaces: with the blur effect on (surfaceAlpha < 1),
          # every app window explicitly opts out so only the shell's layer
          # surfaces blur. Layer rules cannot scope the effect, so this is the
          # exclusion direction that works in Hyprland.
        ]
        ++ lib.optionals glassEnabled [
          {
            match.class = ".*";
            no_blur = true;
          }
        ];

        # Glass shell surfaces: blur the shell's layer-shell namespaces (the
        # bar, panels, toasts, OSD, launcher, tooltips set WlrLayershell
        # .namespace to "marchyo:<surface>"). Registered only when the blur
        # effect is on; ignore_alpha 0.2 keeps the corners outside the pill
        # radius from smearing.
        layer_rule = lib.optionals glassEnabled [
          {
            match.namespace = "marchyo:.*";
            blur = true;
            ignore_alpha = 0.2;
          }
        ];

        bind = [
          (bindd "SUPER + return" "Terminal" (execLua "terminal"))
          (bindd "SUPER + F" "File manager" (execLua "fileManager"))
          (bindd "SUPER + B" "Web browser" (execLua "browser"))
          (bindd "SUPER + M" "Music player" (execLua "music"))
          (bindd "SUPER + E" "Editor" (execLua "editor"))
          (bindd "SUPER + O" "Obsidian" (execLua "notes"))
          (bindd "SUPER + G" "Messenger" (execLua "messenger"))
          # Focus the running 1Password window if there is one, otherwise launch
          # it. The class regex covers both spellings the app reports.
          (bindd "SUPER + slash" "Password manager" (mkLuaInline ''
            function()
              local wins = hl.get_windows({ class = "^(1[pP]assword)$" })
              if #wins > 0 then
                hl.dispatch(hl.dsp.focus({ window = wins[1] }))
              else
                hl.dispatch(hl.dsp.exec_cmd(passwordManager))
              end
            end''))
          (bindd "SUPER + SHIFT + I" "Input method config" (exec "fcitx5-configtool"))
          (bindd "SUPER + SHIFT + C" "Pick color (hex to clipboard)" (exec "marchyo capture color"))
          (bindd "SUPER + SHIFT + L" "Cycle theme" (exec "marchyo theme next"))
          (bindd "SUPER + W" "Close active window" (dsp "window.close()"))
          (bindd "SUPER + J" "Toggle split" (dsp "layout(\"togglesplit\")"))
          (bindd "SUPER + P" "Pseudo window" (dsp "window.pseudo()"))
          (bindd "SUPER + T" "Toggle floating" (dsp "window.float({ action = \"toggle\" })"))
          # Universal clipboard (omarchy parity): send CTRL+Insert / SHIFT+Insert
          # so copy/paste also work in terminals (where CTRL+C is SIGINT)
          (bindd "SUPER + C" "Copy" (dsp "send_shortcut({ mods = \"CTRL\", key = \"Insert\" })"))
          (bindd "SUPER + V" "Paste" (dsp "send_shortcut({ mods = \"SHIFT\", key = \"Insert\" })"))
          (bindd "SUPER + X" "Cut" (dsp "send_shortcut({ mods = \"CTRL\", key = \"X\" })"))
          (bindd "SUPER + left" "Move focus left" (dsp "focus({ direction = \"l\" })"))
          (bindd "SUPER + right" "Move focus right" (dsp "focus({ direction = \"r\" })"))
          (bindd "SUPER + up" "Move focus up" (dsp "focus({ direction = \"u\" })"))
          (bindd "SUPER + down" "Move focus down" (dsp "focus({ direction = \"d\" })"))
        ]
        # Move active window to a workspace with SUPER + SHIFT + [0-9]
        ++ (lib.genList (
          i:
          let
            n = i + 1;
          in
          bindd "SUPER + SHIFT + code:${toString (i + 10)}" "Move window to workspace ${toString n}" (
            dsp "window.move({ workspace = ${toString n} })"
          )
        ) 10)
        ++ [
          (bindd "SUPER + TAB" "Next workspace" (dsp "focus({ workspace = \"e+1\" })"))
          (bindd "SUPER + SHIFT + TAB" "Previous workspace" (dsp "focus({ workspace = \"e-1\" })"))
          (bindd "SUPER + CTRL + TAB" "Former workspace" (dsp "focus({ workspace = \"previous\" })"))
          (bindd "SUPER + SHIFT + left" "Swap window to the left" (dsp "window.swap({ direction = \"l\" })"))
          (bindd "SUPER + SHIFT + right" "Swap window to the right" (
            dsp "window.swap({ direction = \"r\" })"
          ))
          (bindd "SUPER + SHIFT + up" "Swap window up" (dsp "window.swap({ direction = \"u\" })"))
          (bindd "SUPER + SHIFT + down" "Swap window down" (dsp "window.swap({ direction = \"d\" })"))
          (bindd "ALT + Tab" "Cycle to next window" (dsp "window.cycle_next()"))
          (bindd "ALT + SHIFT + Tab" "Cycle to prev window" (dsp "window.cycle_next({ next = false })"))
          (bindd "ALT + Tab" "Reveal active window on top" (dsp "window.alter_zorder({ mode = \"top\" })"))
          (bindd "ALT + SHIFT + Tab" "Reveal active window on top" (
            dsp "window.alter_zorder({ mode = \"top\" })"
          ))
          (bindd "SUPER + mouse_down" "Scroll active workspace forward" (
            dsp "focus({ workspace = \"e+1\" })"
          ))
          (bindd "SUPER + mouse_up" "Scroll active workspace backward" (dsp "focus({ workspace = \"e-1\" })"))

          (bindd "SUPER + ALT + G" "Toggle window grouping" (dsp "group.toggle()"))
          (bindd "SUPER + ALT + SHIFT + G" "Move window out of group" (
            dsp "window.move({ out_of_group = true })"
          ))
          (bindd "SUPER + ALT + left" "Move window into group on left" (
            dsp "window.move({ into_group = \"l\" })"
          ))
          (bindd "SUPER + ALT + right" "Move window into group on right" (
            dsp "window.move({ into_group = \"r\" })"
          ))
          (bindd "SUPER + ALT + up" "Move window into group above" (
            dsp "window.move({ into_group = \"u\" })"
          ))
          (bindd "SUPER + ALT + down" "Move window into group below" (
            dsp "window.move({ into_group = \"d\" })"
          ))
          (bindd "SUPER + ALT + TAB" "Next window in group" (dsp "group.next()"))
          (bindd "SUPER + ALT + SHIFT + TAB" "Previous window in group" (dsp "group.prev()"))

          # Keyboard resize (base resize is border-drag / SUPER+RMB). Descriptions
          # name the edge that moves; negative delta shrinks, positive expands.
          (bindd "SUPER + minus" "Shrink window left" (
            dsp "window.resize({ x = -100, y = 0, relative = true })"
          ))
          (bindd "SUPER + equal" "Expand window right" (
            dsp "window.resize({ x = 100, y = 0, relative = true })"
          ))
          (bindd "SUPER + SHIFT + minus" "Shrink window up" (
            dsp "window.resize({ x = 0, y = -100, relative = true })"
          ))
          (bindd "SUPER + SHIFT + equal" "Expand window down" (
            dsp "window.resize({ x = 0, y = 100, relative = true })"
          ))

          # Extra fullscreen modes (base full screen is SUPER+Page_Up)
          (bindd "SUPER + CTRL + F" "Tiled full screen" (
            dsp "window.fullscreen_state({ internal = 0, client = 2 })"
          ))
          (bindd "SUPER + ALT + F" "Full width" (dsp "window.fullscreen({ mode = \"maximized\" })"))
        ]
        # Move active window silently to a workspace (does not follow)
        ++ (lib.genList (
          i:
          let
            n = i + 1;
          in
          bindd "SUPER + SHIFT + ALT + code:${toString (i + 10)}"
            "Move window silently to workspace ${toString n}"
            (dsp "window.move({ workspace = ${toString n}, follow = false })")
        ) 10)
        ++ [
          # Move whole workspace to an adjacent monitor
          # (single-window monitor move stays on SUPER+SHIFT+comma/period below)
          (bindd "SUPER + SHIFT + ALT + left" "Move workspace to left monitor" (
            dsp "workspace.move({ monitor = \"l\" })"
          ))
          (bindd "SUPER + SHIFT + ALT + right" "Move workspace to right monitor" (
            dsp "workspace.move({ monitor = \"r\" })"
          ))
          (bindd "SUPER + SHIFT + ALT + up" "Move workspace to monitor above" (
            dsp "workspace.move({ monitor = \"u\" })"
          ))
          (bindd "SUPER + SHIFT + ALT + down" "Move workspace to monitor below" (
            dsp "workspace.move({ monitor = \"d\" })"
          ))

          (bindd "CTRL + ALT + TAB" "Focus next monitor" (dsp "focus({ monitor = \"+1\" })"))
          (bindd "CTRL + ALT + SHIFT + TAB" "Focus previous monitor" (dsp "focus({ monitor = \"-1\" })"))

          # Dismiss last notification. With the shell on, mako is retired and the
          # toast list lives in the shell; otherwise makoctl.
          (bindd "SUPER + comma" "Dismiss last notification" (
            exec (if shellEnabled then shellVerb "dismiss" else "makoctl dismiss")
          ))

          (bindd "SUPER + CTRL + Z" "Zoom in" (exec "marchyo zoom in"))
          (bindd "SUPER + CTRL + SHIFT + Z" "Zoom out" (exec "marchyo zoom out"))
          (bindd "SUPER + CTRL + ALT + Z" "Reset zoom" (exec "marchyo zoom reset"))

          # Toggle top bar: the shell bar via `marchyo shell bar`, waybar via
          # SIGUSR1. Guarded so the bind never targets a stood-down daemon.
          (bindd "SUPER + SHIFT + SPACE" "Toggle top bar" (
            exec (if shellEnabled then shellVerb "bar" else "systemctl --user kill -s SIGUSR1 waybar.service")
          ))
          (bindd "SUPER + CTRL + N" "Toggle nightlight" (exec "marchyo toggle nightlight"))
          (bindd "SUPER + CTRL + I" "Toggle idle lock" (exec "marchyo toggle idle"))
          (bindd "SUPER + CTRL + K" "Toggle caffeine (keep awake)" (exec "marchyo toggle caffeine"))
          (bindd "SUPER + ALT + Print" "Toggle screen recording" (exec "marchyo capture record"))

          # Plain binds (no cheat-sheet description)
          (bind "SUPER + Page_Up" (dsp "window.fullscreen({ mode = \"fullscreen\" })"))
        ]
        # Workspace switching
        ++ (lib.genList (
          i:
          let
            n = i + 1;
          in
          bind "SUPER + ${toString n}" (dsp "focus({ workspace = ${toString n}, on_current_monitor = true })")
        ) 5)
        ++ [
          # Drawer (special workspace / scratchpad)
          (bind "SUPER + D" (dsp "workspace.toggle_special(\"magic\")"))
          (bind "SUPER + SHIFT + D" (dsp "window.move({ workspace = \"special:magic\" })"))

          # Session management. With the unified shell on, SUPER+L engages the
          # in-shell WlSessionLock; otherwise hyprlock.
          (bind "SUPER + L" (exec (if shellEnabled then shellVerb "lock" else "hyprlock")))
          (bind "CTRL + ALT + Delete" (exec "systemctl poweroff"))

          # Move active window to an adjacent monitor (monitor focus is CTRL+ALT+Tab;
          # comma/period drive notifications and the emoji picker).
          (bind "SUPER + SHIFT + comma" (dsp "window.move({ monitor = \"-1\" })"))
          (bind "SUPER + SHIFT + period" (dsp "window.move({ monitor = \"+1\" })"))

          (binddOpts "SUPER + mouse:272" "Move window" (dsp "window.drag()") { mouse = true; })
          (binddOpts "SUPER + mouse:273" "Resize window" (dsp "window.resize()") { mouse = true; })
        ]
        ++ (
          # Laptop volume/brightness keys. With the shell on, `marchyo volume` /
          # `marchyo brightness` change the level silently and the shell OSD shows
          # it (brightness through an explicit IPC poke, see the CLI). SwayOSD
          # routes through swayosd-client; with neither, silent wpctl/brightnessctl.
          # `locked` keeps them working over the lock screen, `repeating` allows hold.
          let
            osdEnabled = (((osConfig.marchyo or { }).osd or { }).enable or true) && !shellEnabled;
            elOpts = {
              locked = true;
              repeating = true;
            };
            volumeCommands =
              if shellEnabled then
                {
                  XF86AudioRaiseVolume = "${marchyoCli} volume up";
                  XF86AudioLowerVolume = "${marchyoCli} volume down";
                  XF86AudioMute = "${marchyoCli} volume mute";
                  XF86AudioMicMute = "${marchyoCli} volume mute --mic";
                  XF86MonBrightnessUp = "${marchyoCli} brightness up";
                  XF86MonBrightnessDown = "${marchyoCli} brightness down";
                }
              else if osdEnabled then
                {
                  XF86AudioRaiseVolume = "swayosd-client --output-volume raise";
                  XF86AudioLowerVolume = "swayosd-client --output-volume lower";
                  XF86AudioMute = "swayosd-client --output-volume mute-toggle";
                  XF86AudioMicMute = "swayosd-client --input-volume mute-toggle";
                  XF86MonBrightnessUp = "swayosd-client --brightness raise";
                  XF86MonBrightnessDown = "swayosd-client --brightness lower";
                }
              else
                {
                  XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
                  XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
                  XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
                  XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
                  XF86MonBrightnessUp = "brightnessctl -e4 -n2 set 5%+";
                  XF86MonBrightnessDown = "brightnessctl -e4 -n2 set 5%-";
                };
          in
          lib.mapAttrsToList (key: cmd: bindOpts key (exec cmd) elOpts) volumeCommands
        )
        ++ (
          # Media transport keys. Requires playerctl.
          let
            mediaCommands = {
              XF86AudioNext = "playerctl next";
              XF86AudioPause = "playerctl play-pause";
              XF86AudioPlay = "playerctl play-pause";
              XF86AudioPrev = "playerctl previous";
            };
          in
          lib.mapAttrsToList (key: cmd: bindOpts key (exec cmd) { locked = true; }) mediaCommands
        )
        ++ lib.optionals (dictationEnabled && dictationToggleKey != null) [
          (bindd dictationToggleKey "Dictation toggle" (exec "voxtype record toggle"))
        ]
        ++ lib.optionals dictationStatusWindow [
          (bindd "SUPER + SHIFT + H" "Dictation status" (
            execLua ''terminal .. " --class=org.omarchy.voxtype -e voxtype status --follow"''
          ))
        ]
        # Panel summons via `marchyo shell toggle`. Only wired when the shell is
        # on, since the panels do not exist otherwise.
        ++ lib.optionals shellEnabled [
          (bindd "SUPER + SHIFT + V" "Audio panel" (exec (shellVerb "toggle audio")))
          (bindd "SUPER + SHIFT + N" "Network panel" (exec (shellVerb "toggle network")))
          (bindd "SUPER + SHIFT + B" "Power panel" (exec (shellVerb "toggle power")))
          (bindd "SUPER + SHIFT + M" "Monitor panel" (exec (shellVerb "toggle monitor")))
        ]
        # Launcher binds: in-shell launcher when the shell is on, else vicinae.
        ++ lib.optionals launcherEnabled [
          (bindd "SUPER + CTRL + V" "Clipboard history" (
            exec (
              if shellEnabled then
                shellVerb "launcher clipboard"
              else
                "vicinae vicinae://launch/clipboard/history?toggle=true"
            )
          ))
          (bindd "SUPER + period" "Emoji picker" (
            exec (if shellEnabled then shellVerb "launcher emoji" else "vicinae open --query emoji")
          ))
          (bind "SUPER + R" (exec (if shellEnabled then shellVerb "launcher apps" else "vicinae toggle")))
        ];

        workspace_rule = [
          {
            workspace = "1";
            default = true;
          }
          { workspace = "2"; }
          { workspace = "3"; }
          { workspace = "4"; }
        ];

        env = [
          (env "XCURSOR_SIZE" "24")
          (env "HYPRCURSOR_SIZE" "24")

          # MOZ_ENABLE_WAYLAND and ELECTRON_OZONE_PLATFORM_HINT are set in
          # modules/nixos/wayland.nix at the NixOS session level.
          (env "XDG_SESSION_TYPE" "wayland")
          (env "XDG_CURRENT_DESKTOP" "Hyprland")
          (env "XDG_SESSION_DESKTOP" "Hyprland")

          # XDG_DATA_DIRS is deliberately NOT set here: `env` values render as Lua
          # literals with no shell expansion, so $XDG_DATA_DIRS would be exported
          # verbatim and uwsm would push that literal into the systemd user manager,
          # breaking .desktop and icon lookup. NixOS already provides the full list via
          # environment.profileRelativeSessionVariables.XDG_DATA_DIRS.

          # Use XCompose file (absolute: no tilde expansion happens here either)
          (env "XCOMPOSEFILE" "${config.home.homeDirectory}/.XCompose")
        ]
        # NVIDIA GPU environment variables for Wayland
        ++ lib.optionals hasNvidia [
          (env "LIBVA_DRIVER_NAME" "nvidia")
          (env "__GLX_VENDOR_LIBRARY_NAME" "nvidia")
          (env "NVD_BACKEND" "direct")
        ]
        # NVIDIA PRIME offload mode
        ++ lib.optionals isPrimeOffload [
          (env "__NV_PRIME_RENDER_OFFLOAD" "1")
          (env "__VK_LAYER_NV_optimus" "NVIDIA_only")
        ];

        # Startup applications, wrapped in an `hl.on("hyprland.start", ...)`
        # hook. Kept as a single-element list so other modules can append their
        # own hooks instead of colliding on the `on` key.
        on = [
          (onStart (
            [
              "kanshi"
              # vicinae runs as a user service (programs.vicinae.systemd.enable)
              "fcitx5 -d --replace"

              "wl-paste --type text --watch cliphist store"
              "wl-paste --type image --watch cliphist store"

              "1password --silent"
            ]
            ++ lib.optionals wallpaperEnabled [
              "${pkgs.awww}/bin/awww-daemon --format xrgb"
              "${setWallpaper}"
            ]
            ++ lib.optionals cliEnabled [
              "marchyo runtime restore"
            ]
          ))
        ];
      };
    };

    home.packages =
      with pkgs;
      [
        wl-clipboard
        wl-clip-persist
        cliphist
        wtype

        nwg-look

        wf-recorder

        slurp
        brightnessctl
        playerctl
        pavucontrol
        pwvucontrol

        xdg-utils
        mimeo

        nerd-fonts.blex-mono
        nerd-fonts.caskaydia-cove

        killall
        pciutils
        usbutils
        hyprpicker # Wayland color picker (see color-pick bind below)
        imv # lightweight Wayland image viewer
        gpu-screen-recorder # low-overhead GPU screen recorder (replay buffer)

        libnotify
        kanshi

        wireplumber

        power-profiles-daemon
      ]
      ++ lib.optionals wallpaperEnabled [
        awww
        wallpaperPackage
      ];

    services.hyprpolkitagent.enable = true;
    services.hyprsunset.enable = true;
    # Keyring is provided + PAM-unlocked by the NixOS module; the HM user daemon
    # too would start a second gnome-keyring-daemon ("already initialized").
    services.gnome-keyring.enable = false;
  };
}
