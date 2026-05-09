{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let

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

  # Convert "#RRGGBB" → "rgb(RRGGBB)" / "rgba(RRGGBBAA)" for Hyprland color syntax
  rgb = h: "rgb(${lib.removePrefix "#" h})";
  rgba = h: a: "rgba(${lib.removePrefix "#" h}${a})";

  marchyoDefaults = (osConfig.marchyo or { }).defaults or { };

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
      m = marchyoDefaults.musicPlayer or "spotify";
    in
    if m == null then "xdg-open" else musicHyprlandCommands.${m};

in
{
  config = {

    gtk = {
      enable = true;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # UWSM manages systemd integration
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
        # Layout — Jylhis Design System (tokens.json spacing)
        general = {
          gaps_in = 6;
          gaps_out = 12;
          border_size = 2;

          "col.active_border" =
            lib.mkForce "${rgba palette.hex.accent "ff"} ${rgba palette.hex.brand "ff"} 45deg";
          "col.inactive_border" = lib.mkForce (rgba palette.hex."border-strong" "aa");

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

        # Decoration — flat paper aesthetic, no blur, minimal shadow
        decoration = {
          rounding = 4;

          # Dim inactive instead of opacity — paper metaphor
          dim_inactive = true;
          dim_strength = 0.08;

          shadow = {
            enabled = true;
            range = 8;
            render_power = 2;
            offset = "0 2";
            color = lib.mkForce (if isDark then "rgba(00000066)" else "rgba(2c2825aa)");
            color_inactive = lib.mkForce (if isDark then "rgba(00000022)" else "rgba(2c282544)");
          };

          blur = {
            enabled = false;
          };
        };

        # Motion — Jylhis Design System tokens (tokens.json motion)
        animations = {
          enabled = true;

          bezier = [
            "fast, 0.25, 0.1, 0.25, 1.0"
            "base, 0.2, 0.6, 0.2, 1.0"
            "slow, 0.16, 1.0, 0.3, 1.0"
            "spring, 0.34, 1.25, 0.64, 1.0"
          ];

          animation = [
            "windows, 1, 2.5, base, popin 90%"
            "windowsOut, 1, 1.5, fast, popin 98%"
            "border, 1, 2.0, base"
            "borderangle, 0"
            "fade, 1, 1.5, fast"
            "workspaces, 1, 2.5, slow, slidefade 12%"
            "specialWorkspace, 1, 3.0, spring, slidefadevert -20%"
          ];
        };

        dwindle = {
          pseudotile = true;
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

          # Only a subtle opacity change, but not for video sites
          "opacity 1.0 0.97, match:tag chromium-based-browser"
          "opacity 1.0 0.97, match:tag firefox-based-browser"

          # Video apps: remove chromium browser tag so they don't get opacity applied
          "tag -chromium-based-browser, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"
          "tag -default-opacity, match:class (chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)"

          # Floating windows
          "float on, match:tag floating-window"
          "center on, match:tag floating-window"
          "size 875 600, match:tag floating-window"

          "tag +floating-window, match:class (org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)"
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

          "opacity 0.97 0.9, match:class .*"

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
          "SUPER, D, Lazy Docker, exec, $terminal -e lazydocker"
          "SUPER, G, Messenger, exec, $messenger"
          "SUPER, slash, Password manager, exec, $passwordManager"
          "SUPER SHIFT, I, Input method config, exec, fcitx5-configtool"
          "SUPER, W, Close active window, killactive,"
          "SUPER, J, Toggle split, togglesplit,"
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

          # Special workspace (scratchpad)
          "SUPER, S, togglespecialworkspace, magic"
          "SUPER SHIFT, S, movetoworkspace, special:magic"

          # Session management
          "SUPER, L, exec, hyprlock"
          "CTRL ALT, Delete, exec, systemctl poweroff"

          # Monitor focus
          "SUPER, comma, focusmonitor, -1"
          "SUPER, period, focusmonitor, +1"
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
          "vicinae server"
          "fcitx5 -d --replace"

          # Clipboard
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"

          "1password --silent"
        ];
      };
    };

    # Additional packages for Hyprland
    home.packages = with pkgs; [
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

      # System integration
      libnotify
      kanshi

      # Audio
      wireplumber

      # Power management
      power-profiles-daemon
    ];

    services.hyprpolkitagent.enable = true;
    services.hyprsunset.enable = true;
    services.gnome-keyring.enable = true;
  };
}
