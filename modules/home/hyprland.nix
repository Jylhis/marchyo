{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let

  # Desktop shell modules only apply on Linux with the marchyo desktop enabled.
  # On darwin (isLinux false) and on headless Linux hosts (desktop disabled) this
  # whole module is inert, so consumers no longer need to `disabledModules` it.
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # GPU detection from NixOS config
  hasNvidia = builtins.elem "nvidia" (osConfig.marchyo.graphics.vendors or [ ]);
  isPrimeOffload =
    (osConfig.marchyo.graphics.prime.enable or false)
    && (osConfig.marchyo.graphics.prime.mode or "") == "offload";

  # Theme variant for color selection
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

  # Convert "#RRGGBB" → "rgb(RRGGBB)" / "rgba(RRGGBBAA)" for Hyprland color syntax
  rgb = h: "rgb(${lib.removePrefix "#" h})";
  rgba = h: a: "rgba(${lib.removePrefix "#" h}${a})";

  marchyoDefaults = (osConfig.marchyo or { }).defaults or { };

  aiToolingEnabled = (import ../../lib/ai.nix osConfig).featureEnabled "tooling" true;

  dictationEnabled = ((osConfig.marchyo or { }).dictation or { }).enable or false;
  dictationToggleKey = ((osConfig.marchyo or { }).dictation or { }).toggleKey or "SUPER CTRL, X";
  dictationStatusWindow =
    dictationEnabled && (((osConfig.marchyo or { }).dictation or { }).statusWindow or true);

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

  musicHyprlandCommands = {
    # TUI clients launch in a floating terminal (Omarchy pattern, see window rule below)
    spotify-player = "$terminal --class=org.omarchy.spotify-player -e spotify-player";
    ncspot = "$terminal --class=org.omarchy.ncspot -e ncspot";
    spotify = "spotify";
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

in
{
  config = lib.mkIf desktopEnabled {

    gtk = {
      enable = true;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # UWSM manages systemd integration
      # Pin to the legacy renderer; the `settings` attrset below is
      # written for hyprlang. Migrating to "lua" is a separate change.
      configType = "hyprlang";
      settings = {

        # Default apps

        "$notes" = lib.mkDefault "obsidian";
        "$browser" = lib.mkDefault browserCmd;
        "$fileManager" = lib.mkDefault fileManagerCmd;
        "$messenger" = lib.mkDefault "signal-desktop";
        "$music" = lib.mkDefault musicCmd;
        "$passwordManager" = lib.mkDefault "1password";
        "$webapp" = lib.mkDefault "$browser --app";
        "$terminal" = lib.mkDefault "ghostty";

        ecosystem.no_update_news = true;
        xwayland.force_zero_scaling = true;

        monitor = lib.mkAfter [
          ", preferred, auto, 1, vrr, 1"
        ];

        # Enhanced input configuration
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
                  # Handle both list and string types for variant
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
          sensitivity = 0;
          touchpad = {
            natural_scroll = false;
            disable_while_typing = true;
            tap-to-click = true;
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
        # Layout — tmux-style TUI grid: zero gaps, single-line pane borders
        general = {
          gaps_in = 0;
          gaps_out = 0;
          border_size = 2;

          # Solid accent border on the active pane, dim border on the rest —
          # mirrors a tmux active/inactive pane divider (no gradient). The
          # inactive border uses the border-strong token, matching the design
          # system's Hyprland variant files (text-faint is an ink token and
          # reads brighter than a border should on Roast).
          "col.active_border" = lib.mkForce (rgba palette.hex.accent "ff");
          "col.inactive_border" = lib.mkForce (rgba palette.hex."border-strong" "ff");

          resize_on_border = true;
          hover_icon_on_border = true;
          allow_tearing = true;

          layout = "dwindle";
        };

        render = {
          direct_scanout = true;
        };

        cursor = lib.mkIf hasNvidia {
          no_hardware_cursors = true;
        };

        # Decoration — flat TUI panes: sharp corners, no rounding/shadow/blur
        decoration = {
          rounding = 0;

          # No dimming — every pane stays fully readable like a terminal grid;
          # the active pane is identified by its bright accent border instead.
          dim_inactive = false;

          shadow = {
            enabled = false;
          };

          blur = {
            enabled = false;
          };
        };

        # Motion — disabled for instant, terminal-multiplexer-style snapping
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

        # Window rules
        windowrule = [
          # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
          "suppress_event maximize, match:class .*"

          # Browser types
          "tag +chromium-based-browser, match:class ((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)"
          "tag +firefox-based-browser, match:class ([fF]irefox|zen|librewolf)"
          "tag -default-opacity, match:tag chromium-based-browser"
          "tag -default-opacity, match:tag firefox-based-browser"

          # Force chromium-based browsers into a tile to deal with --app bug
          "tile on, match:tag chromium-based-browser"

          # Video apps: remove chromium browser tag so they don't get opacity applied
          "tag -chromium-based-browser, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"
          "tag -default-opacity, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"

          # Floating windows
          "float on, match:tag floating-window"
          "center on, match:tag floating-window"
          "size 875 600, match:tag floating-window"

          "tag +floating-window, match:class (org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.spotify-player|org.omarchy.ncspot|org.omarchy.aichat|org.omarchy.voxtype|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)"
          "tag +floating-window, match:class (xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus), match:title ^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)"

          # Fullscreen screensaver
          "fullscreen 1, match:class Screensaver"

          # Float Steam, fullscreen RetroArch
          "float on, match:class steam"
          "center on, match:class steam, match:title Steam"
          "tag -default-opacity, match:class steam.*"
          "opacity 1 1, match:class steam.*"
          "size 1100 700, match:class steam, match:title Steam"
          "size 460 800, match:class steam, match:title Friends List"

          # 1Password - full opacity for proper rendering
          "no_screen_share on, match:class ^(1[p|P]assword)$"
          "tag +floating-window, match:class ^(1[p|P]assword)$"

          "opacity 1.0 1.0, match:class .*"

          # Picture-in-picture overlays
          "tag +pip, match:title (Picture.?in.?[Pp]icture)"
          "tag -default-opacity, match:tag pip"
          "float on, match:tag pip"
          "pin on, match:tag pip"
          "size 600 338, match:tag pip"
          "keep_aspect_ratio on, match:tag pip"
          "border_size 0, match:tag pip"
          "opacity 1 1, match:tag pip"
          "move (monitor_w-window_w-40) (monitor_h*0.04), match:tag pip"
        ];

        bindd = [
          "SUPER, return, Terminal, exec, $terminal"
          "SUPER, F, File manager, exec, $fileManager"
          "SUPER, B, Web browser, exec, $browser"
          "SUPER, M, Music player, exec, $music"
          "SUPER, E, Emacs, exec, emacsclient -c -a emacs"
          "SUPER, O, Obsidian, exec, $notes"
          "SUPER, G, Messenger, exec, $messenger"
          "SUPER, slash, Password manager, exec, hyprctl dispatch focuswindow class:^(1password)$ || $passwordManager"
          "SUPER SHIFT, I, Input method config, exec, fcitx5-configtool"
          "SUPER SHIFT, C, Pick color (hex to clipboard), exec, hyprpicker -a"
          "SUPER, W, Close active window, killactive,"
          "SUPER, J, Toggle split, layoutmsg, togglesplit"
          "SUPER, P, Pseudo window, pseudo,"
          "SUPER, V, Toggle floating, togglefloating,"
          "SUPER, left, Move focus left, movefocus, l"
          "SUPER, right, Move focus right, movefocus, r"
          "SUPER, up, Move focus up, movefocus, u"
          "SUPER, down, Move focus down, movefocus, d"
          # Move active window to a workspace with SUPER + SHIFT + [0-9]
          "SUPER SHIFT, code:10, Move window to workspace 1, movetoworkspace, 1"
          "SUPER SHIFT, code:11, Move window to workspace 2, movetoworkspace, 2"
          "SUPER SHIFT, code:12, Move window to workspace 3, movetoworkspace, 3"
          "SUPER SHIFT, code:13, Move window to workspace 4, movetoworkspace, 4"
          "SUPER SHIFT, code:14, Move window to workspace 5, movetoworkspace, 5"
          "SUPER SHIFT, code:15, Move window to workspace 6, movetoworkspace, 6"
          "SUPER SHIFT, code:16, Move window to workspace 7, movetoworkspace, 7"
          "SUPER SHIFT, code:17, Move window to workspace 8, movetoworkspace, 8"
          "SUPER SHIFT, code:18, Move window to workspace 9, movetoworkspace, 9"
          "SUPER SHIFT, code:19, Move window to workspace 10, movetoworkspace, 10"
          # Tab between workspaces
          "SUPER, TAB, Next workspace, workspace, e+1"
          "SUPER SHIFT, TAB, Previous workspace, workspace, e-1"
          "SUPER CTRL, TAB, Former workspace, workspace, previous"
          # Swap active window with the one next to it with SUPER + SHIFT + arrow keys
          "SUPER SHIFT, left, Swap window to the left, swapwindow, l"
          "SUPER SHIFT, right, Swap window to the right, swapwindow, r"
          "SUPER SHIFT, up, Swap window up, swapwindow, u"
          "SUPER SHIFT, down, Swap window down, swapwindow, d"
          # Cycle through applications on active workspace
          "ALT, Tab, Cycle to next window, cyclenext"
          "ALT SHIFT, Tab, Cycle to prev window, cyclenext, prev"
          "ALT, Tab, Reveal active window on top, bringactivetotop"
          "ALT SHIFT, Tab, Reveal active window on top, bringactivetotop"
          # Scroll through existing workspaces with SUPER + scroll
          "SUPER, mouse_down, Scroll active workspace forward, workspace, e+1"
          "SUPER, mouse_up, Scroll active workspace backward, workspace, e-1"

          # --- Window grouping (tabbed/stacked windows) ---
          "SUPER ALT, G, Toggle window grouping, togglegroup"
          "SUPER ALT SHIFT, G, Move window out of group, moveoutofgroup"
          "SUPER ALT, left, Move window into group on left, moveintogroup, l"
          "SUPER ALT, right, Move window into group on right, moveintogroup, r"
          "SUPER ALT, up, Move window into group above, moveintogroup, u"
          "SUPER ALT, down, Move window into group below, moveintogroup, d"
          "SUPER ALT, TAB, Next window in group, changegroupactive, f"
          "SUPER ALT SHIFT, TAB, Previous window in group, changegroupactive, b"

          # --- Keyboard resize (base resize is via border-drag / SUPER+RMB) ---
          "SUPER, minus, Expand window left, resizeactive, -100 0"
          "SUPER, equal, Shrink window left, resizeactive, 100 0"
          "SUPER SHIFT, minus, Shrink window up, resizeactive, 0 -100"
          "SUPER SHIFT, equal, Expand window down, resizeactive, 0 100"

          # --- Extra fullscreen modes (base full screen is SUPER+Page_Up) ---
          "SUPER CTRL, F, Tiled full screen, fullscreenstate, 0 2"
          "SUPER ALT, F, Full width, fullscreen, 1"

          # --- Move active window silently to a workspace (does not follow) ---
          "SUPER SHIFT ALT, code:10, Move window silently to workspace 1, movetoworkspacesilent, 1"
          "SUPER SHIFT ALT, code:11, Move window silently to workspace 2, movetoworkspacesilent, 2"
          "SUPER SHIFT ALT, code:12, Move window silently to workspace 3, movetoworkspacesilent, 3"
          "SUPER SHIFT ALT, code:13, Move window silently to workspace 4, movetoworkspacesilent, 4"
          "SUPER SHIFT ALT, code:14, Move window silently to workspace 5, movetoworkspacesilent, 5"
          "SUPER SHIFT ALT, code:15, Move window silently to workspace 6, movetoworkspacesilent, 6"
          "SUPER SHIFT ALT, code:16, Move window silently to workspace 7, movetoworkspacesilent, 7"
          "SUPER SHIFT ALT, code:17, Move window silently to workspace 8, movetoworkspacesilent, 8"
          "SUPER SHIFT ALT, code:18, Move window silently to workspace 9, movetoworkspacesilent, 9"
          "SUPER SHIFT ALT, code:19, Move window silently to workspace 10, movetoworkspacesilent, 10"

          # --- Move whole workspace to an adjacent monitor ---
          # (single-window monitor move stays on SUPER+SHIFT+comma/period below)
          "SUPER SHIFT ALT, left, Move workspace to left monitor, movecurrentworkspacetomonitor, l"
          "SUPER SHIFT ALT, right, Move workspace to right monitor, movecurrentworkspacetomonitor, r"
          "SUPER SHIFT ALT, up, Move workspace to monitor above, movecurrentworkspacetomonitor, u"
          "SUPER SHIFT ALT, down, Move workspace to monitor below, movecurrentworkspacetomonitor, d"

          # --- Monitor focus (relocated here from SUPER+comma/period) ---
          "CTRL ALT, TAB, Focus next monitor, focusmonitor, +1"
          "CTRL ALT SHIFT, TAB, Focus previous monitor, focusmonitor, -1"

          # --- Clipboard history / emoji picker (both via vicinae) ---
          "SUPER CTRL, V, Clipboard history, exec, vicinae vicinae://launch/clipboard/history?toggle=true"
          "SUPER, period, Emoji picker, exec, vicinae open --query emoji"

          # --- Notifications (mako) ---
          "SUPER, comma, Dismiss last notification, exec, makoctl dismiss"
          "SUPER CTRL, comma, Dismiss all notifications, exec, makoctl dismiss --all"

          # --- Cursor zoom (screen magnifier) ---
          "SUPER CTRL, Z, Zoom in, exec, marchyo-zoom in"
          "SUPER CTRL SHIFT, Z, Zoom out, exec, marchyo-zoom out"
          "SUPER CTRL ALT, Z, Reset zoom, exec, marchyo-zoom reset"

          # --- System toggles (backed by modules/home/window-toggles.nix) ---
          "SUPER SHIFT, SPACE, Toggle top bar, exec, systemctl --user kill -s SIGUSR1 waybar.service"
          "SUPER CTRL, N, Toggle nightlight, exec, marchyo-nightlight-toggle"
          "SUPER CTRL, I, Toggle idle lock, exec, marchyo-idle-toggle"
          "SUPER ALT, Print, Toggle screen recording, exec, marchyo-screenrecord-toggle"
        ]
        ++ lib.optionals aiToolingEnabled [
          "SUPER, A, AI chat, exec, $terminal --class=org.omarchy.aichat -e marchyo-aichat"
        ]
        ++ lib.optionals (dictationEnabled && dictationToggleKey != null) [
          "${dictationToggleKey}, Dictation toggle, exec, voxtype record toggle"
        ]
        ++ lib.optionals dictationStatusWindow [
          "SUPER SHIFT, H, Dictation status, exec, $terminal --class=org.omarchy.voxtype -e voxtype status --follow"
        ];
        bind = [
          "SUPER, R, exec, vicinae toggle"

          "SUPER, Page_Up, fullscreen, 0"

          # Workspace switching
          "SUPER, 1, focusworkspaceoncurrentmonitor, 1"
          "SUPER, 2, focusworkspaceoncurrentmonitor, 2"
          "SUPER, 3, focusworkspaceoncurrentmonitor, 3"
          "SUPER, 4, focusworkspaceoncurrentmonitor, 4"
          "SUPER, 5, focusworkspaceoncurrentmonitor, 5"

          # Drawer (special workspace / scratchpad)
          "SUPER, D, togglespecialworkspace, magic"
          "SUPER SHIFT, D, movetoworkspace, special:magic"

          # Session management
          "SUPER, L, exec, hyprlock"
          "CTRL ALT, Delete, exec, systemctl poweroff"

          # Move active window to an adjacent monitor (single window).
          # Monitor *focus* is on CTRL+ALT+Tab (see bindd); comma/period now
          # drive notifications (comma) and the emoji picker (period).
          "SUPER SHIFT, comma, movewindow, mon:-1"
          "SUPER SHIFT, period, movewindow, mon:+1"

        ];
        bindel = [
          # Laptop multimedia keys for volume and LCD brightness
          ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
          ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
        ];
        bindl = [
          # Requires playerctl
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPrev, exec, playerctl previous"
        ];

        # Mouse bindings
        bindmd = [
          "SUPER, mouse:272, Move window, movewindow"
          "SUPER, mouse:273, Resize window, resizewindow"
        ];

        # Workspace configuration
        workspace = [
          "1, default:true"
          "2"
          "3"
          "4"
        ];

        # Environment variables for optimal performance
        env = [
          # Cursor size
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"

          # MOZ_ENABLE_WAYLAND and ELECTRON_OZONE_PLATFORM_HINT are set in
          # modules/nixos/wayland.nix at the NixOS session level.
          "XDG_SESSION_TYPE,wayland"
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_DESKTOP,Hyprland"

          # Make .desktop files available for the launcher and discovery tools
          "XDG_DATA_DIRS,$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"

          # Use XCompose file
          "XCOMPOSEFILE,~/.XCompose"
        ]
        # NVIDIA GPU environment variables for Wayland
        ++ lib.optionals hasNvidia [
          "LIBVA_DRIVER_NAME,nvidia"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "NVD_BACKEND,direct"
        ]
        # NVIDIA PRIME offload mode
        ++ lib.optionals isPrimeOffload [
          "__NV_PRIME_RENDER_OFFLOAD,1"
          "__VK_LAYER_NV_optimus,NVIDIA_only"
        ];

        # Startup applications
        exec-once = [
          # Essential services
          "kanshi"
          # vicinae runs as a user service (programs.vicinae.systemd.enable)
          "fcitx5 -d --replace"

          # Clipboard
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"

          "1password --silent"
        ]
        ++ lib.optionals wallpaperEnabled [
          "${pkgs.awww}/bin/awww-daemon --format xrgb"
          "${setWallpaper}"
        ];
      };
    };

    # Additional packages for Hyprland
    home.packages =
      with pkgs;
      [
        # Core Wayland tools
        wl-clipboard
        wl-clip-persist
        cliphist

        nwg-look

        # Screen recording
        wf-recorder

        slurp
        # System monitoring and control
        brightnessctl
        playerctl
        pavucontrol
        pwvucontrol

        # File management
        xdg-utils
        mimeo

        # Fonts
        nerd-fonts.jetbrains-mono
        nerd-fonts.caskaydia-cove

        # Utilities
        killall
        pciutils
        usbutils
        hyprpicker # Wayland color picker (see color-pick bind below)
        imv # lightweight Wayland image viewer
        gpu-screen-recorder # low-overhead GPU screen recorder (replay buffer)

        # System integration
        libnotify
        kanshi

        # Audio
        wireplumber

        # Power management
        power-profiles-daemon
      ]
      ++ lib.optionals wallpaperEnabled [
        awww
        wallpaperPackage
      ];

    services.hyprpolkitagent.enable = true;
    services.hyprsunset.enable = true;
    services.gnome-keyring.enable = true;
  };
}
