# Vicinae application launcher — marchyo-owned config.
#
# Configures the upstream home-manager module (wired into
# home-manager.sharedModules by outputs.nix). Everything under `settings` is
# written to a store JSON that reaches the daemon through VICINAE_OVERRIDES;
# every leaf is mkDefault so `marchyo.launcher.settings` (or a consumer's own
# programs.vicinae.settings) can override it.
#
# Two upstream key names are easy to get wrong, and the daemon ignores unknown
# keys silently rather than failing:
#   * the window block is `launcher_window`, NOT `window`
#   * the font size is `font.normal.size`, NOT `font.size`
# tests/eval/launcher.nix asserts both, because marchyo shipped the wrong pair
# for a while and nothing caught it.
#
# Theming is marchyo's, not Stylix's (the vicinae target is disabled in
# modules/generic/theme.nix): both variants are registered as real Vicinae TOML
# themes derived from the Jylhis design tokens via
# modules/generic/jylhis-palette.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyo = osConfig.marchyo or { };
  cfg = marchyo.launcher or { };

  enabled = pkgs.stdenv.isLinux && (marchyo.desktop.enable or false) && (cfg.enable or false);

  themeVariant = marchyo.theme.variant or "dark";
  fontScale = marchyo.theme.fontScale or 1.0;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };

  mkPalette = variant: import ../generic/jylhis-palette.nix { inherit pkgs lib variant; };

  # Vicinae's recognized colour keys (src/server/src/theme/theme-parser.cpp
  # RECOGNIZED_KEYS). Anything outside this set emits an "unused config key"
  # diagnostic at load, so the nesting below is exact.
  mkTheme =
    variant:
    let
      p = mkPalette variant;
      c = p.hex;
      a = p.ansi;
    in
    {
      meta = {
        name = if variant == "dark" then "Jylhis Field" else "Jylhis Sheet";
        description =
          "Jylhis Design System v2 (The Survey) — "
          + (if variant == "dark" then "Field (dark) ground" else "Sheet (light) ground")
          + ", bronze interactive accent.";
        inherit variant;
        # `inherits` supplies any key marchyo leaves unset. `meta.version` is
        # deliberately absent: the parser does not read it and would flag it.
        inherits = if variant == "dark" then "vicinae-dark" else "vicinae-light";
      };

      colors = {
        core = {
          inherit (c) accent;
          accent_foreground = c.bg;
          background = c.bg;
          foreground = c.text;
          secondary_background = c.surface;
          inherit (c) border;
        };

        shortcut.border = c."border-strong";

        # `contour` is v2's structural linework token — never interaction, which
        # is exactly what a window chrome border is.
        main_window = {
          border = c.contour;
          footer.background = c."bg-subtle";
        };
        settings_window.border = c.contour;

        accents = {
          inherit (a)
            blue
            green
            magenta
            red
            yellow
            cyan
            ;
          # No orange/purple tokens in the design system. `brand` (benchmark
          # vermilion) is the only true orange and stays clear of both ansi
          # yellow and red; status-warn would just duplicate yellow. Used here
          # purely as a palette slot, not as the brand mark.
          orange = c.brand;
          purple = c."syn-keyword";
        };

        text = {
          default = c.text;
          muted = c."text-muted";
          danger = c."status-err";
          success = c."status-ok";
          placeholder = c."text-faint";
          links = {
            default = c."status-info";
            visited = c."syn-keyword";
          };
          selection = {
            background = c."selection-bg";
            foreground = c.text;
          };
        };

        input = {
          background = c."bg-subtle";
          inherit (c) border;
          border_focus = c.accent;
          border_error = c."status-err";
        };

        button.primary = {
          background = c.accent;
          foreground = c.bg;
          hover = {
            background = c."accent-hover";
            foreground = c.bg;
          };
          focus.outline = c.accent;
        };

        list.item = {
          hover = {
            background = c.surface;
            foreground = c.text;
            secondary_foreground = c."text-muted";
          };
          selection = {
            background = c."surface-raised";
            foreground = c."text-heading";
            secondary_background = c.surface;
            secondary_foreground = c."text-muted";
          };
        };

        grid.item = {
          background = c.surface;
          hover.outline = c."border-strong";
          selection.outline = c.accent;
        };

        scrollbars = {
          background = c.surface;
          secondary_background = c."bg-subtle";
        };

        tooltip = {
          background = c."surface-raised";
          foreground = c.text;
          inherit (c) border;
        };

        loading = {
          bar = c.accent;
          spinner = c.accent;
        };
      };
    };

  activeTheme = if themeVariant == "dark" then "jylhis-field" else "jylhis-sheet";

  keybinding = cfg.keybinding or "emacs";

  # In emacs mode Ctrl+N is navigate-down and Ctrl+P navigate-up, matched with
  # "exactly Ctrl" semantics. That collides head-on with the stock action.new
  # (control+N) and open-search-filter (control+P), so move those two off Ctrl.
  # Ctrl+Shift+P (action.pin) and Ctrl+B (toggle-action-panel) are unaffected:
  # emacs left/right are Ctrl+Alt+B / Ctrl+Alt+F.
  emacsKeybindFixups = {
    "action.new" = "control+shift+N";
    "open-search-filter" = "control+shift+F";
  };

  # Root-search housekeeping entries. Provider-level `enabled = false` wins over
  # entrypoint-level, so the single-command `theme` provider is disabled whole.
  declutterProviders = {
    theme.enabled = false;
    vicinae.entrypoints = {
      sponsor.enabled = false; # "Donate to Vicinae"
      report-bug.enabled = false; # "Report a Bug"
      about.enabled = false; # "About"
    };
  };
in
{
  config = lib.mkIf enabled {
    programs.vicinae = {
      enable = true;
      systemd = {
        # Run the daemon as a user service (Restart=always, WantedBy=graphical-session.target).
        enable = true;

        # The daemon resolves helper binaries store-relative only and never looks
        # in /run/wrappers/bin, so the setcap'd input server has to be named
        # explicitly. Without this the daemon runs the unwrapped binary, fails to
        # open /dev/uinput, and emoji/clipboard paste silently degrades to
        # clipboard-only. The wrapper comes from modules/nixos/launcher.nix.
        environment = lib.mkIf (cfg.inputServer.enable or true) {
          VICINAE_INPUT_SERVER_BIN = "/run/wrappers/bin/vicinae-input-server";
        };
      };

      # Both variants are always registered so a marchyo.theme.variant flip
      # needs no theme rebuild.
      themes = {
        jylhis-field = mkTheme "dark";
        jylhis-sheet = mkTheme "light";
      };

      settings = lib.mkMerge [
        {
          # Vicinae picks light-vs-dark at runtime from Qt's reported colour
          # scheme and treats "unknown" as dark, which under Hyprland can
          # disagree with the rest of the desktop. Pinning both slots to the
          # variant marchyo built for is what keeps the launcher in step.
          theme = {
            dark.name = lib.mkDefault activeTheme;
            light.name = lib.mkDefault activeTheme;
          };

          # TUI aesthetic — opaque, square corners, hairline border.
          launcher_window = {
            opacity = lib.mkDefault 1.0;
            rounding = lib.mkDefault 0;
            material = lib.mkDefault "none";
            client_side_decorations.border_width = lib.mkDefault 1;
          };

          # Hanken Grotesk is the v2 body face; keep in sync with the
          # serif/sansSerif mapping in modules/generic/stylix.nix.
          font.normal = {
            family = lib.mkDefault "Hanken Grotesk";
            size = lib.mkDefault (fs.round 12);
          };

          keybinding = lib.mkDefault keybinding;

          telemetry.system_info = lib.mkDefault (cfg.telemetry.enable or false);

          # Upstream defaults this off on Linux.
          encrypt_sensitive_data = lib.mkDefault true;
          # marchyo ships fcitx5 CJK layouts; without this the launcher ignores
          # in-progress IME preedit text.
          consider_preedit = lib.mkDefault true;
          close_on_focus_loss = lib.mkDefault true;
          pop_to_root_on_close = lib.mkDefault true;
          # Upstream's "twenty" ships every bookmark/quicklink domain to a third
          # party to fetch an icon.
          favicon_service = lib.mkDefault "none";
        }

        (lib.mkIf (keybinding == "emacs") {
          keybinds = lib.mapAttrs (_: lib.mkDefault) emacsKeybindFixups;
        })

        (lib.mkIf (cfg.declutter or true) { providers = declutterProviders; })

        (cfg.settings or { })
      ];
    };
  };
}
