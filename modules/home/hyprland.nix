{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let

  # Inert on headless Linux, so consumers never need disabledModules.
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # The marchyo CLI persists ephemeral runtime overrides (theme/toggle
  # changes made without --apply); restore them at session start.
  cliEnabled = (osConfig.marchyo or { }).cli.enable or false;
  # A clipboard plugin that replaces the native history keeps its own, so
  # cliphist stops capturing.
  cliphistEnabled =
    !((((osConfig.marchyo or { }).shell or { }).replacedRoles or { }) ? "launcher.clipboard");

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

  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;

  # Glass surfaces: marchyo.theme.appearance.surfaceAlpha < 1 makes the shell's
  # cards translucent, which only reads as glass when the compositor blurs what
  # is behind them. Baked off (alpha 1) the blur effect stays disabled and no
  # layer rules are registered, reproducing the flat opaque look.
  surfaceAlpha = ((osConfig.marchyo or { }).theme.appearance or { }).surfaceAlpha or 1.0;
  # Reduced motion (VM default): no animations, blur or transparency.
  reduceMotion = ((osConfig.marchyo or { }).theme.appearance or { }).reduceMotion or false;
  glassShell = shellEnabled && surfaceAlpha < 1.0 && !reduceMotion;

  # Window appearance (marchyo.theme.appearance.{transparency,corners,animations}).
  appearanceCfg = (osConfig.marchyo or { }).theme.appearance or { };
  transparency = appearanceCfg.transparency or "opaque";
  corners = appearanceCfg.corners or "theme";
  animationsMode = appearanceCfg.animations or "auto";
  gaps = appearanceCfg.gaps or false;
  glassyWindows = transparency == "glassy" && !reduceMotion;
  seeThroughWindows = transparency != "opaque" && !reduceMotion;
  # Blur serves the shell's glass surfaces and glassy windows.
  glassEnabled = glassShell || glassyWindows;
  animationsEnabled =
    if animationsMode == "on" then
      true
    else if animationsMode == "off" then
      false
    else
      shellEnabled && !reduceMotion;
  # animations = "auto": decided at session start, since a VM is not known at build time.
  autoAnimationsInVm = animationsMode == "auto" && animationsEnabled;
  vmAnimationsOff = pkgs.writeShellScript "marchyo-vm-animations-off" ''
    ${pkgs.systemd}/bin/systemd-detect-virt -q || exit 0
    exec hyprctl eval 'hl.config({ animations = { enabled = false } })'
  '';

  # Lua-renderer helpers (env/onStart, see lib/hyprland-lua.nix). The binds
  # come from the bind table (lib/keybinds.nix, modules/home/keybinds.nix).
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  inherit (hlua)
    mkLuaInline
    env
    onStart
    ;

  # Every settings.env entry must carry `_args = [ <name> <value> ]` so Home
  # Manager's Lua renderer emits a two-argument `hl.env(<name>, <value>)` call.
  # Any other shape renders as a single table argument — most painfully the
  # legacy hyprlang entry `{ n = ...; v = ...; }`, which becomes
  # `hl.env({ n = ..., v = ... })` and aborts Hyprland's Lua chunk on load,
  # silently dropping every setting after it. A module cannot rewrite the
  # merged value of an option it also defines (self-reference), so reject the
  # shape at eval time instead of letting the session die at runtime.
  envSetting = config.wayland.windowManager.hyprland.settings.env or null;
  envEntries =
    if lib.isList envSetting then envSetting else lib.optionals (envSetting != null) [ envSetting ];
  envArgRenderable =
    arg: lib.isString arg || (lib.isAttrs arg && (arg._type or null) == "lua-inline");
  envEntryOk =
    entry:
    lib.isAttrs entry
    && entry ? _args
    && builtins.isList entry._args
    && builtins.length entry._args == 2
    && lib.all envArgRenderable entry._args;
  badEnvEntries = lib.filter (e: !envEntryOk e) envEntries;

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

  # Per-monitor workspaces (marchyo.workspaces.perMonitor): each monitor owns a
  # block of ten workspace ids. hyprland-monitor-workspaces.lua is loaded with
  # dofile from the store, so `hyprland --verify-config` runs it too, and the
  # connectors of marchyo.monitors seed the block order.
  perMonitorWorkspaces = ((osConfig.marchyo or { }).workspaces or { }).perMonitor or true;
  workspaceSeed = map (m: m.output) (lib.filter (m: m.enable && m.output != "") monitorCfg);
  monitorWorkspacesLua = mkLuaInline "dofile(${hlua.luaStr "${./hyprland-monitor-workspaces.lua}"})(${
    lib.generators.toLua { multiline = false; } workspaceSeed
  })";
  # Display panel settings (marchyo.monitorPanel.persist): the saved file is
  # loaded from the end of the generated config, after the declarative monitor
  # rules.
  monitorPanelPersist = ((osConfig.marchyo or { }).monitorPanel or { }).persist or true;
  monitorSettingsLoader = "dofile(${hlua.luaStr "${./hyprland-monitor-settings.lua}"})()";
in
{
  config = lib.mkIf desktopEnabled {

    assertions = [
      {
        assertion = badEnvEntries == [ ];
        message = ''
          wayland.windowManager.hyprland.settings.env entries must be two-argument calls written as { _args = [ <name> <value> ]; }, which render as hl.env(<name>, <value>) (the `env` helper in marchyo's lib/hyprland-lua.nix produces this shape). Any other attrset renders as a single table argument: the legacy hyprlang shape { n = ...; v = ...; } becomes hl.env({ n = ..., v = ... }), and Hyprland's Lua chunk aborts on that first error, silently dropping every setting after it (monitors, window rules, autostarts).
          Offending entries:
          ${lib.concatMapStringsSep "\n" (lib.generators.toPretty { }) badEnvEntries}'';
      }
    ];

    gtk = {
      enable = true;
    };

    # The declarative appearance the CLI restores on `--revert`
    # (`marchyo theme transparency|corners|gaps|icons`, `marchyo font set --kind ui`, `marchyo toggle animations`).
    xdg.configFile."marchyo/appearance.json".text = builtins.toJSON {
      inherit
        transparency
        corners
        reduceMotion
        gaps
        ;
      iconTheme = if config.gtk.iconTheme != null then config.gtk.iconTheme.name else null;
      fontName =
        if config.gtk.font != null then
          lib.concatStringsSep " " (
            [ config.gtk.font.name ]
            ++ lib.optional (config.gtk.font.size != null) (toString config.gtk.font.size)
          )
        else
          null;
      animations = animationsEnabled;
      shellGlass = glassShell;
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
            # A restarted marchyo-shell may take over a session lock that
            # its predecessor held (Services/Lock.qml stranded-lock recovery).
            allow_session_lock_restore = true;
          };
          # tmux-style TUI grid: zero gaps unless marchyo.theme.appearance.gaps.
          general = {
            gaps_in = if gaps then 5 else 0;
            gaps_out = if gaps then 10 else 0;
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

          # Non-KMS dmabuf formats stay in the feedback; dropping them lets a
          # monitor hotplug disconnect Mesa clients.
          quirks = {
            skip_non_kms_dmabuf_formats = false;
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
            rounding = if corners == "rounded" then 6 else 0;

            # No dimming; the active pane is identified by its accent border instead.
            dim_inactive = false;

            shadow = {
              enabled = false;
            };
          }
          // lib.optionalAttrs (corners == "rounded") {
            rounding_power = 3;
          }
          // lib.optionalAttrs seeThroughWindows {
            active_opacity = 0.92;
            inactive_opacity = 0.85;
          }
          // lib.optionalAttrs glassEnabled {
            blur = {
              enabled = true;
              size = 4;
              passes = 2;
            };
          };

          # Off for instant, terminal-multiplexer-style snapping. With the shell
          # on, short popin animations run on the curve/animation leaves below.
          animations = {
            enabled = animationsEnabled;
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
            match.class = "(org.omarchy.bluetui|org.omarchy.nmtui|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.spotify-player|org.omarchy.voxtype|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)";
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
        ++ lib.optionals (glassShell && !glassyWindows) [
          {
            match.class = ".*";
            no_blur = true;
          }
        ]
        # Opaque windows, so nothing behind a window is blended into it.
        ++ lib.optionals reduceMotion [
          {
            match.class = ".*";
            opacity = "1 1";
          }
        ];

        # Glass shell surfaces: blur the shell's layer-shell namespaces (the
        # bar, panels, toasts, OSD, launcher, tooltips set WlrLayershell
        # .namespace to "marchyo:<surface>"). Registered only when the blur
        # effect is on; ignore_alpha 0.2 keeps the corners outside the pill
        # radius from smearing.
        layer_rule =
          lib.optionals glassEnabled [
            {
              match.namespace = "marchyo:.*";
              blur = true;
              ignore_alpha = 0.2;
            }
          ]
          # Per-surface animation styles. Layers fade by default; the panels,
          # launcher and OSD map without a QML transition, so they pop in; the
          # bar slides from its edge; toasts and tooltips animate themselves in
          # QML, so the compositor stays out of the way. Screenshot region
          # selection (slurp) and hyprpicker never animate, so no fading overlay
          # lands in a capture.
          ++ lib.optionals shellEnabled [
            {
              match.namespace = "marchyo:(panel|launcher|osd)";
              animation = "popin 90%";
            }
            {
              match.namespace = "marchyo:bar";
              animation = "slide";
            }
            {
              match.namespace = "marchyo:(notifs|tooltip)";
              no_anim = true;
            }
            {
              match.namespace = "selection|hyprpicker";
              no_anim = true;
            }
          ];

        # Shell animations: one snappy, slightly overshooting "popin" bezier
        # drives short window and layer animations. Workspace switches and
        # border colour changes stay instant.
        curve = lib.mkIf shellEnabled [
          {
            _args = [
              "popin"
              {
                type = "bezier";
                points = [
                  [
                    0.05
                    0.9
                  ]
                  [
                    0.1
                    1.05
                  ]
                ];
              }
            ];
          }
        ];

        animation = lib.mkIf shellEnabled [
          {
            leaf = "global";
            enabled = true;
            speed = 3;
            bezier = "popin";
          }
          {
            leaf = "windows";
            enabled = true;
            speed = 2.5;
            bezier = "popin";
            style = "popin 85%";
          }
          {
            leaf = "layers";
            enabled = true;
            speed = 2;
            bezier = "popin";
            style = "fade";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 2;
            bezier = "default";
          }
          {
            leaf = "border";
            enabled = false;
          }
          {
            leaf = "workspaces";
            enabled = false;
          }
        ];
      }
      # Per-monitor workspaces replace the global default-workspace rule.
      // (
        if perMonitorWorkspaces then
          { marchyoWorkspaces._var = monitorWorkspacesLua; }
        else
          {
            workspace_rule = [
              {
                workspace = "1";
                default = true;
              }
              { workspace = "2"; }
              { workspace = "3"; }
              { workspace = "4"; }
            ];
          }
      )
      // {
        # Two-argument hl.env(name, value) calls: each entry must be
        # `{ _args = [ <name> <value> ]; }` (the `env` helper above). Legacy
        # hyprlang `{ n, v }` entries are rejected at eval time (see the
        # assertion in this module) because the Lua renderer would emit a
        # single-table call that aborts Hyprland's config load.
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
            ]
            ++ lib.optionals cliphistEnabled [
              "wl-paste --type text --watch cliphist store"
              "wl-paste --type image --watch cliphist store"
            ]
            ++ [
              "1password --silent"
            ]
            ++ lib.optionals wallpaperEnabled [
              "${pkgs.awww}/bin/awww-daemon --format xrgb"
              "${setWallpaper}"
            ]
            ++ lib.optionals autoAnimationsInVm [
              "${vmAnimationsOff}"
            ]
            ++ lib.optionals cliEnabled [
              "marchyo runtime restore"
            ]
          ))
        ];
      };

      extraConfig = lib.mkIf monitorPanelPersist monitorSettingsLoader;
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

    # With the shell on, the shell is the session's polkit agent
    # (shell/Services/Polkit.qml) and a session holds only one.
    services.hyprpolkitagent.enable = !shellEnabled;
    services.hyprsunset.enable = true;
    # Keyring is provided + PAM-unlocked by the NixOS module; the HM user daemon
    # too would start a second gnome-keyring-daemon ("already initialized").
    services.gnome-keyring.enable = false;
  };
}
