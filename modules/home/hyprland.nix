{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkDefault;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  variant = if config ? colorScheme then config.colorScheme.variant else "dark";

  # GPU detection from NixOS config
  hasNvidia = builtins.elem "nvidia" (osConfig.marchyo.graphics.vendors or [ ]);
  isPrimeOffload =
    (osConfig.marchyo.graphics.prime.enable or false)
    && (osConfig.marchyo.graphics.prime.mode or "") == "offload";

  # Helper to convert hex to rgb() format (Hyprland accepts hex directly)
  rgb = color: "rgb(${color})";
in
{
  config = {

    home.pointerCursor = {
      gtk.enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    qt = {
      style = {
        name = mkDefault (if variant == "light" then "adwaita" else "adwaita-dark");
        package = pkgs.adwaita-qt;
      };
    };

    gtk = {
      enable = true;

      theme = {
        name = mkDefault (if variant == "light" then "Adwaita" else "Adwaita-dark");
        package = pkgs.gnome-themes-extra;
      };

      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = if variant == "light" then "prefer-light" else "prefer-dark";
        gtk-theme = if variant == "light" then "Adwaita" else "Adwaita-dark";
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      settings = {

        # Default apps

        "$notes" = lib.mkDefault "obsidian";
        "$browser" = lib.mkDefault "brave --new-window --ozone-platform=wayland";
        "$fileManager" = lib.mkDefault "nautilus --new-window";
        "$messenger" = lib.mkDefault "signal-desktop";
        "$music" = lib.mkDefault "spotify";
        "$passwordManager" = lib.mkDefault "1password";
        "$webapp" = lib.mkDefault "$browser --app";
        "$terminal" = lib.mkDefault "kitty";

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
        };
        # Performance-optimized general settings
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;

          "col.active_border" = mkDefault (
            if colors != null then rgb colors.base0D else "rgba(33ccffee) rgba(00ff99ee) 45deg"
          );
          "col.inactive_border" = mkDefault (if colors != null then rgb colors.base03 else "rgba(595959aa)");
          resize_on_border = false;
          allow_tearing = true;

          layout = "dwindle";
        };

        render = {
          direct_scanout = true;
        };

        # Modern decorations with performance considerations
        decoration = {
          rounding = 0;
          active_opacity = 1.0;
          inactive_opacity = 0.95;
          fullscreen_opacity = 1.0;

          shadow = {
            enabled = true;
            range = 2;
            render_power = 3;
            color = mkDefault (if colors != null then rgb colors.base00 else "rgba(1a1a1aee)");
          };

          blur = {
            enabled = true;
            size = 3;
            passes = 1;

            vibrancy = 0.1696;
          };
        };

        # Smooth, professional animations
        animations = {
          enabled = true;

          bezier = [
            "easeOutQuint,0.23,1,0.32,1"
            "easeInOutCubic,0.65,0.05,0.36,1"
            "linear,0,0,1,1"
            "almostLinear,0.5,0.5,0.75,1.0"
            "quick,0.15,0,0.1,1"
            "easeinoutsine, 0.37, 0, 0.63, 1"
            "fluent_decel, 0, 0.2, 0.4, 1"
            "easeOutCirc, 0, 0.55, 0.45, 1"
            "easeOutCubic, 0.33, 1, 0.68, 1"
          ];

          animation = [
            "border, 1, 2.7, easeOutCirc"
            "windows, 1, 4.79, easeOutQuint"
            "windowsMove, 1, 2, easeinoutsine, slide"
            "windowsIn, 1, 3, easeOutCubic, popin 30%"
            "windowsOut, 1, 3, fluent_decel, popin 70%"
            "fadeIn, 1, 3, easeOutCubic"
            "fadeOut, 1, 2, easeOutCubic"
            "fadeSwitch, 1, 2, easeOutCirc"
            "fadeShadow, 1, 2, easeOutCirc"
            "fadeDim, 1, 3, fluent_decel"
            "fade, 1, 3.03, quick"
            "layers, 1, 3.81, easeOutQuint"
            "layersIn, 1, 4, easeOutQuint, fade"
            "layersOut, 1, 1.5, linear, fade"
            "fadeLayersIn, 1, 1.79, almostLinear"
            "fadeLayersOut, 1, 1.39, almostLinear"
            "workspaces, 1, 2, fluent_decel, slide"
            "specialWorkspace, 1, 3, fluent_decel, slidevert"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
          force_split = 2;
        };
        # dwindle = {

        #   smart_split = false;
        #   smart_resizing = true;

        #   special_scale_factor = 0.9;
        #   split_width_multiplier = 1.2;
        #   use_active_for_splits = true;
        # };

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

          # Just dash of transparency
          "opacity 0.97 0.9, match:class .*"

          # 1Password
          #"noscreenshare, class:^(1Password)$"

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
          # Quick access applications
          # "SUPER, B, exec, $browser"
          # "SUPER, T, exec, $terminal"
          # "SUPER, F, exec, $fileManager"
          # "SUPER, M, exec, $music"
          # "SUPER, G, exec, emacsclient -cF '((visibility . nil))' -e '(emacs-run-launcher)'"

          # Application launcher - matching Plasma's Meta key
          "SUPER, R, exec, vicinae toggle"

          # Window management
          # "SUPER, J, togglesplit"
          # "SUPER, P, pseudo"
          # "SUPER, V, togglefloating"
          # "SUPER, Q, killactive"

          # Window focus - matching Plasma's Meta+Alt+Arrow
          # "SUPER, Left, movefocus, l"
          # "SUPER, Right, movefocus, r"
          # "SUPER, Up, movefocus, u"
          # "SUPER, Down, movefocus, d"

          # Window tiling - matching Plasma's Meta+Arrow
          # "SUPER ALT, Left, movewindow, l"
          # "SUPER ALT, Right, movewindow, r"
          # "SUPER ALT, Up, movewindow, u"
          # "SUPER ALT, Down, movewindow, d"

          # Window maximize/minimize
          "SUPER, Page_Up, fullscreen, 0" # Maximize Window
          # "SUPER, Page_Down, movetoworkspacesilent, special" # Window Minimize equivalent

          # Workspace switching
          "SUPER, 1, focusworkspaceoncurrentmonitor, 1"
          "SUPER, 2, focusworkspaceoncurrentmonitor, 2"
          "SUPER, 3, focusworkspaceoncurrentmonitor, 3"
          "SUPER, 4, focusworkspaceoncurrentmonitor, 4"
          "SUPER, 5, focusworkspaceoncurrentmonitor, 5"
          "SUPER, comma, workspace, -1"
          "SUPER, period, workspace, +1"

          # Window resizing
          # "SUPER CTRL, H, resizeactive, -20 0"
          # "SUPER CTRL, L, resizeactive, 20 0"
          # "SUPER CTRL, K, resizeactive, 0 -20"
          # "SUPER CTRL, J, resizeactive, 0 20"

          # Move windows to workspaces
          # "SUPER SHIFT, 1, movetoworkspace, 1"
          # "SUPER SHIFT, 2, movetoworkspace, 2"
          # "SUPER SHIFT, 3, movetoworkspace, 3"
          # "SUPER SHIFT, 4, movetoworkspace, 4"

          # Special workspace (scratchpad)
          "SUPER, S, togglespecialworkspace, magic"
          "SUPER SHIFT, S, movetoworkspace, special:magic"
          # "SUPER, grave, togglespecialworkspace, magic"
          # "SUPER SHIFT, grave, movetoworkspace, special:magic"
          # "SUPER, minus, togglespecialworkspace, term"
          # "SUPER SHIFT, minus, movetoworkspace, special:term"

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

          # Special workspaces
          # "special:magic, gapsout:50"
          # "special:term, gapsout:30, gapsin:10"
        ];

        # Environment variables for optimal performance
        env = [
          # Cursor size
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"

          # Cursor theme
          "XCURSOR_THEME,Adwaita"
          "HYPRCURSOR_THEME,Adwaita"

          # Wayland native performance (conservative)
          "MOZ_ENABLE_WAYLAND,1"
          "ELECTRON_OZONE_PLATFORM_HINT,auto"
          "XDG_SESSION_TYPE,wayland"
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_DESKTOP,Hyprland"

          # Make .desktop files available for wofi
          "XDG_DATA_DIRS,$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"

          # Use XCompose file
          "XCOMPOSEFILE,~/.XCompose"
        ]
        ++ lib.optionals (config ? colorScheme) [
          "GTK_THEME,${if variant == "light" then "Adwaita" else "Adwaita-dark"}"
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
          "hyprpaper"

          # Clipboard
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"

          # Authentication and system
          # "nm-applet"
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

      # Wallpaper and theming
      wallust
      pywal
      nwg-look

      # Screen recording
      wf-recorder

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

      # Development tools integration
      git-cliff
      lazygit

      # System integration
      libnotify
      kanshi

      # Network
      networkmanagerapplet

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
