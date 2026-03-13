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

  marchyoDefaults = (osConfig.marchyo or { }).defaults or { };

  browserCommands = {
    brave = "brave --new-window --ozone-platform=wayland";
    google-chrome = "google-chrome --new-window --ozone-platform=wayland";
    firefox = "firefox --new-window";
    chromium = "chromium --new-window --ozone-platform=wayland";
  };

  fileManagerCommands = {
    nautilus = "nautilus --new-window";
    thunar = "thunar";
  };

  musicCommands = {
    spotify = "spotify";
  };

  browserCmd =
    let
      b = marchyoDefaults.browser or "google-chrome";
    in
    if b == null then "xdg-open" else browserCommands.${b};

  fileManagerCmd =
    let
      fm = marchyoDefaults.fileManager or "nautilus";
    in
    if fm == null then "xdg-open" else fileManagerCommands.${fm};

  musicCmd =
    let
      m = marchyoDefaults.musicPlayer or "spotify";
    in
    if m == null then "spotify" else musicCommands.${m};

  # XKB keyboard config from home.keyboard (set by modules/home/keyboard.nix)
  hasKbLayout =
    (config.home ? keyboard)
    && (config.home.keyboard ? layout)
    && (config.home.keyboard.layout != null);
  hasKbVariant =
    (config.home ? keyboard)
    && (config.home.keyboard ? variant)
    && (config.home.keyboard.variant != null);
  hasKbOptions =
    (config.home ? keyboard)
    && (config.home.keyboard ? options)
    && (config.home.keyboard.options != null);

  xkbLayout = lib.optionalString hasKbLayout config.home.keyboard.layout;
  xkbVariant = lib.optionalString hasKbVariant (
    if builtins.isList config.home.keyboard.variant then
      lib.strings.concatStringsSep "," config.home.keyboard.variant
    else
      config.home.keyboard.variant
  );
  xkbOptions = lib.optionalString hasKbOptions (
    lib.strings.concatStringsSep "," config.home.keyboard.options
  );

in
{
  config = {

    gtk.enable = true;

    programs.niri.settings = {
      environment = {
        MOZ_ENABLE_WAYLAND = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "niri";
        XDG_SESSION_DESKTOP = "niri";
        XDG_DATA_DIRS = "$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share";
        XCOMPOSEFILE = "~/.XCompose";
        XCURSOR_SIZE = "24";
      }
      // lib.optionalAttrs hasNvidia {
        LIBVA_DRIVER_NAME = "nvidia";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        NVD_BACKEND = "direct";
      }
      // lib.optionalAttrs isPrimeOffload {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

      input = {
        keyboard = {
          xkb = {
            layout = lib.mkIf hasKbLayout xkbLayout;
            variant = lib.mkIf hasKbVariant xkbVariant;
            options = lib.mkIf hasKbOptions xkbOptions;
          };
        };
        touchpad = {
          tap = true;
          natural-scroll = false;
          scroll-factor = 0.5;
          dwt = true;
        };
        mouse = {
          accel-profile = "flat";
          accel-speed = 0.0;
        };
      };

      prefer-no-csd = true;

      screenshot-path = "${config.home.homeDirectory}/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

      hotkey-overlay.skip-at-startup = true;

      layout = {
        gaps = 10;
        focus-ring = {
          width = 2;
        };
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
          { proportion = 1.0; }
        ];
        center-focused-column = "never";
      };

      animations = {
        workspace-switch = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 1000;
            epsilon = 0.0001;
          };
        };
        window-open = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
        window-close = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
        horizontal-view-movement = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
        window-movement = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
        window-resize = {
          kind.spring = {
            damping-ratio = 1.0;
            stiffness = 800;
            epsilon = 0.0001;
          };
        };
      };

      window-rules = [
        # Default: subtle transparency for most windows
        {
          matches = [ { } ];
          opacity = 0.97;
        }
        # Browsers: active full opacity, inactive slightly dim
        {
          matches = [
            { app-id = "^(google-chrome|chromium|brave-browser|firefox|zen)"; }
          ];
          opacity = 0.97;
        }
        # Steam: full opacity
        {
          matches = [ { app-id = "^steam"; } ];
          opacity = 1.0;
        }
        # 1Password: full opacity, block from screencast
        {
          matches = [ { app-id = "^1[pP]assword$"; } ];
          opacity = 1.0;
          block-out-from = "screencast";
        }
        # Picture-in-picture: full opacity, always on top
        {
          matches = [ { title = "Picture.?in.?[Pp]icture"; } ];
          opacity = 1.0;
        }
      ];

      binds =
        let
          sh = cmd: { action.spawn-sh = cmd; };
          shLocked = cmd: {
            allow-when-locked = true;
            action.spawn-sh = cmd;
          };
        in
        {
          # Applications
          "Mod+Return".action.spawn = "kitty";
          "Mod+B" = sh browserCmd;
          "Mod+F" = sh fileManagerCmd;
          "Mod+M" = sh musicCmd;
          "Mod+G".action.spawn = "signal-desktop";
          "Mod+O".action.spawn = "obsidian";
          "Mod+Slash".action.spawn = [
            "1password"
            "--toggle"
          ];
          "Mod+Shift+I".action.spawn = "fcitx5-configtool";

          # Launcher
          "Mod+R".action.spawn = [
            "vicinae"
            "toggle"
          ];

          # Window management
          "Mod+W".action.close-window = { };
          "Mod+V".action.toggle-window-floating = { };
          "Mod+Shift+F".action.fullscreen-window = { };
          "Mod+Page_Up".action.maximize-column = { };

          # Focus movement
          "Mod+Left".action.focus-column-left = { };
          "Mod+Right".action.focus-column-right = { };
          "Mod+Up".action.focus-window-up = { };
          "Mod+Down".action.focus-window-down = { };

          # Move columns
          "Mod+Shift+Left".action.move-column-left = { };
          "Mod+Shift+Right".action.move-column-right = { };
          "Mod+Shift+Up".action.move-window-up = { };
          "Mod+Shift+Down".action.move-window-down = { };

          # Workspace switching
          "Mod+1".action.focus-workspace = 1;
          "Mod+2".action.focus-workspace = 2;
          "Mod+3".action.focus-workspace = 3;
          "Mod+4".action.focus-workspace = 4;
          "Mod+5".action.focus-workspace = 5;
          "Mod+Tab".action.focus-workspace-down = { };
          "Mod+Shift+Tab".action.focus-workspace-up = { };

          # Move column to workspace
          "Mod+Shift+1".action.move-column-to-workspace = 1;
          "Mod+Shift+2".action.move-column-to-workspace = 2;
          "Mod+Shift+3".action.move-column-to-workspace = 3;
          "Mod+Shift+4".action.move-column-to-workspace = 4;
          "Mod+Shift+5".action.move-column-to-workspace = 5;

          # Monitor focus
          "Mod+Comma".action.focus-monitor-left = { };
          "Mod+Period".action.focus-monitor-right = { };
          "Mod+Shift+Comma".action.move-column-to-monitor-left = { };
          "Mod+Shift+Period".action.move-column-to-monitor-right = { };

          # Column width
          "Mod+Minus".action.set-column-width = "-10%";
          "Mod+Equal".action.set-column-width = "+10%";
          "Mod+J".action.switch-preset-column-width = { };

          # Column operations (consume/expel windows)
          "Mod+BracketLeft".action.consume-or-expel-window-left = { };
          "Mod+BracketRight".action.consume-or-expel-window-right = { };

          # Cycle focus
          "Alt+Tab".action.focus-column-right-or-first = { };
          "Alt+Shift+Tab".action.focus-column-left-or-last = { };

          # Session management
          "Mod+L".action.spawn = "swaylock";
          "Ctrl+Alt+Delete".action.spawn = [
            "systemctl"
            "poweroff"
          ];

          # Screenshots (built-in niri actions)
          "Print".action.screenshot = { };
          "Shift+Print".action.screenshot-window = { };
          "Ctrl+Print".action.screenshot-screen = { };

          # Volume
          "XF86AudioRaiseVolume" = shLocked "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = shLocked "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = shLocked "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          "XF86AudioMicMute" = shLocked "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

          # Brightness
          "XF86MonBrightnessUp" = shLocked "brightnessctl -e4 -n2 set 5%+";
          "XF86MonBrightnessDown" = shLocked "brightnessctl -e4 -n2 set 5%-";

          # Media keys
          "XF86AudioNext" = shLocked "playerctl next";
          "XF86AudioPrev" = shLocked "playerctl previous";
          "XF86AudioPlay" = shLocked "playerctl play-pause";
          "XF86AudioPause" = shLocked "playerctl play-pause";
        };

      spawn-at-startup = [
        { command = [ "kanshi" ]; }
        {
          command = [
            "vicinae"
            "server"
          ];
        }
        {
          command = [
            "fcitx5"
            "-d"
            "--replace"
          ];
        }
        {
          command = [
            "wl-paste"
            "--type"
            "text"
            "--watch"
            "cliphist"
            "store"
          ];
        }
        {
          command = [
            "wl-paste"
            "--type"
            "image"
            "--watch"
            "cliphist"
            "store"
          ];
        }
        {
          command = [
            "1password"
            "--silent"
          ];
        }
        { command = [ "xwayland-satellite" ]; }
        {
          command = [
            "wlsunset"
            "-l"
            "60"
            "-L"
            "24"
          ];
        }
      ];
    };

    home.packages = with pkgs; [
      # Core Wayland tools
      wl-clipboard
      wl-clip-persist
      cliphist

      # Screen lock
      swaylock

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

      # X11 compatibility
      xwayland-satellite

      # Night light
      wlsunset
    ];

    services.gnome-keyring.enable = true;
  };
}
