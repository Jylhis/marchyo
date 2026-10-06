{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Closed plugin kind set, kind -> manifest entryPoints key (pure data, so
  # this platform-neutral declaration stays Darwin-safe).
  pluginKinds = import ../../../packages/marchyo-shell/plugin-kinds.nix;
  pluginKindsDoc = lib.concatStringsSep ", " (
    lib.mapAttrsToList (k: key: "`${k}` (entry point `${key}`)") pluginKinds
  );

  # Raw, IFD-free spec for a CLI-added plugin: pinned git source plus manifest
  # fields. No pkgs references, per the darwin eval gate; marchyo-shell.nix
  # turns each spec into a built plugin via mkMarchyoShellPlugin on Linux.
  extraPluginType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Plugin manifest id (must be outside the reserved marchyo.* namespace).";
      };
      url = mkOption {
        type = types.str;
        description = "Git URL the plugin is fetched from.";
      };
      rev = mkOption {
        type = types.str;
        description = "Pinned git revision.";
      };
      hash = mkOption {
        type = types.str;
        description = "fetchgit hash (SRI or sha256) pinning the source.";
      };
      kinds = mkOption {
        type = types.listOf (types.enum (lib.attrNames pluginKinds));
        description = "Manifest kinds, from ${pluginKindsDoc}.";
      };
      entryPoints = mkOption {
        type = types.attrsOf types.str;
        description = "Manifest entry points: exactly one QML file per declared kind, keyed by that kind's entry point key.";
      };
      prefix = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Launcher query prefix, required for the `launcher` kind and null otherwise. It must not start with a first-party prefix character (`=`, `>`, `#`, `!`).";
      };
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display name (defaults to the id when null).";
      };
      version = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Plugin version string (defaults to \"0\" when null).";
      };
    };
  };

  # Typed schema for shell.json (marchyo.shell.settings). Every level is a
  # freeform submodule, so keys the schema does not name pass through to
  # shell.json unchanged. Typed leaves default to null and are dropped from the
  # rendered file when unset (modules/home/marchyo-shell.nix), so the shell's
  # own defaults apply. Pure lib types only, per the darwin eval gate.
  freeform = types.attrsOf types.anything;

  widgetEntryType = types.submodule {
    freeformType = freeform;
    options = {
      id = mkOption {
        type = types.str;
        example = "marchyo.clock";
        description = "Widget id: a first-party `marchyo.*` id or a declared plugin's bar-widget id.";
      };
      settings = mkOption {
        type = types.nullOr freeform;
        default = null;
        description = "Per-entry widget settings, handed to the widget as its `settings` object.";
      };
    };
  };

  sectionOption =
    name:
    mkOption {
      type = types.nullOr (types.listOf widgetEntryType);
      default = null;
      description = "Widgets in the ${name} bar section, in order. Null keeps the shipped default section.";
    };

  barType = types.submodule {
    freeformType = freeform;
    options = {
      layout = mkOption {
        type = types.submodule {
          freeformType = freeform;
          options = {
            left = sectionOption "left";
            center = sectionOption "center";
            right = sectionOption "right";
          };
        };
        default = { };
        description = "Bar layout: `left`, `center`, and `right` widget sections.";
      };
      style = mkOption {
        type = types.nullOr (
          types.enum [
            "flat"
            "segmented"
          ]
        );
        default = null;
        example = "segmented";
        description = ''
          Bar look. `flat` draws the widgets straight on the bar surface;
          `segmented` fills each cluster of widgets between separators with a
          background that alternates between the theme's subtle-background
          colour and an accent-tinted surface colour, joined by curved edges. Presentation only: the
          layout is the same in both. Null keeps the shell default (`flat`).
        '';
      };
    };
  };

  barOption = mkOption {
    type = barType;
    default = { };
    description = "Top bar configuration.";
  };

  # A per-monitor override: the per-output subset of the settings schema.
  # The always-global keys (idle, caffeine, monitors) are not declared, and
  # the shell ignores them here (shell/Commons/MonitorConfig.js).
  monitorType = types.submodule {
    freeformType = freeform;
    options.bar = barOption;
  };

  settingsType = types.submodule {
    freeformType = freeform;
    options = {
      bar = barOption;

      idle = mkOption {
        type = types.submodule {
          freeformType = freeform;
          options = {
            screensaver = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
              description = "Seconds of idle before the screensaver (shell default 150).";
            };
            lock = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
              description = "Seconds of idle before the lock (shell default 300).";
            };
          };
        };
        default = { };
        description = "Idle thresholds. Always global.";
      };

      caffeine = mkOption {
        type = types.submodule {
          freeformType = freeform;
          options.autoVideo = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Hold an idle inhibitor while a video plays (shell default true).";
          };
        };
        default = { };
        description = "Caffeine (idle inhibitor) behaviour. Always global.";
      };

      monitors = mkOption {
        type = types.attrsOf monitorType;
        default = { };
        example = lib.literalExpression ''
          {
            "HDMI-A-1".bar.layout.right = [ { id = "marchyo.clock"; } ];
          }
        '';
        description = ''
          Per-output overrides keyed by output name (as in `hyprctl monitors`).
          Each entry is merged over the global settings for that output only:
          objects merge key by key, lists (such as a bar section) replace the
          global value whole. `idle`, `caffeine`, and `monitors` are always
          global and are ignored here.
        '';
      };
    };
  };
in
{
  options.marchyo.shell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Experimental unified Quickshell desktop shell. When enabled, a single
        long-running Quickshell process renders the Jylhis-themed top bar
        (workspaces, clock, tray, audio, battery, network, bluetooth, CPU,
        power profile), the OSD, the audio/network/power/monitor panels, and
        the notification toasts — replacing waybar, SwayOSD, and mako (each
        mutually exclusive; see tests/eval/marchyo-shell.nix). Opt-in and off
        by default; it is not cascaded from `marchyo.desktop.enable`.
        Vicinae (launcher) and hyprlock (lock) stay. See shell/README.md for
        the roadmap.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression ''
        [
          (pkgs.mkMarchyoShellPlugin {
            src = pkgs.fetchgit { url = "https://example.com/acme-weather.git"; rev = "..."; hash = "..."; };
            id = "acme.weather";
            kinds = [ "bar-widget" ];
            entryPoints = { barWidget = "Panel.qml"; };
          })
        ]
      '';
      description = ''
        Shell plugins baked into the store shell (build-time Option A model:
        Nix-declared, store-baked, never discovered at runtime). Each entry is a
        `pkgs.mkMarchyoShellPlugin` derivation. Declared plugins are copied under
        the shell's `plugins/` tree, listed in a generated
        `Commons/PluginIndex.qml`, and recorded in
        `share/marchyo/shell/plugins.lock.json`. Kinds are ${pluginKindsDoc}.
        A `bar-widget` plugin becomes referenceable from
        `marchyo.shell.settings.bar.layout` by its manifest id, a `launcher`
        plugin adds a launcher provider selected by its `prefix`, and a
        `daemon` plugin is instantiated once at the shell root. Changing the
        list requires a rebuild. Empty by default.
      '';
    };

    extraPlugins = mkOption {
      type = types.listOf extraPluginType;
      default = [ ];
      example = lib.literalExpression ''
        [
          {
            id = "acme.weather";
            url = "https://example.com/acme-weather.git";
            rev = "0000000000000000000000000000000000000000";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            kinds = [ "bar-widget" ];
            entryPoints = { barWidget = "Panel.qml"; };
          }
        ]
      '';
      description = ''
        Additive plugin specs appended to `plugins`, built into
        `pkgs.mkMarchyoShellPlugin` derivations on Linux (see
        modules/home/marchyo-shell.nix). Kept separate from `plugins` — and
        expressed as raw pinned git specs rather than derivations — so the
        additive source (`marchyo plugin add`, which persists here through the
        marchyoCliState sidecar at mkDefault priority) never replaces the
        flake-declared `plugins` list. Empty by default.
      '';
    };

    settings = lib.mkOption {
      type = settingsType;
      default = { };
      example = lib.literalExpression ''
        {
          bar.layout.right = [
            { id = "marchyo.clock"; }
            { id = "marchyo.battery"; }
          ];
          idle = { screensaver = 150; lock = 300; };
          monitors."HDMI-A-1".bar.layout.right = [ { id = "marchyo.clock"; } ];
        }
      '';
      description = ''
        Runtime shell configuration, serialized to a generated (read-only)
        `~/.config/marchyo/shell.json` that the shell reads live (watched, so a
        rebuild's new layout applies without restarting the shell). This is the
        build-time Option A model: reproducible, but re-read at runtime.

        Recognised keys:
        - `bar.layout.{left,center,right}` — arrays of `{ id; settings?; }`
          widget entries. Ids are the first-party widget ids (e.g.
          `marchyo.clock`, `marchyo.battery`) or a declared shell plugin's
          bar-widget id. Any section left unset falls back to the shipped
          default layout.
        - `bar.style`: `flat` (the shell default) or `segmented`, two-tone
          cluster backgrounds with curved joins.
        - `idle.{screensaver,lock}` — idle thresholds in seconds.
        - `caffeine.autoVideo` — hold an idle inhibitor while a video plays
          (default `true`).
        - `monitors.<output>`: per-output overrides (e.g. `bar.layout` or
          `bar.style`), merged
          over the global values for that output. `idle`, `caffeine`, and
          `monitors` are always global.

        Recognised keys are typed; any other key passes through to shell.json
        unchanged. Unset typed keys are left out of the file, so the shell's
        defaults apply. Leave empty (the default) to use the shipped bar layout unchanged.
      '';
    };
  };
}
