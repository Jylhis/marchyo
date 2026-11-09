{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Closed plugin kind set, kind -> manifest entryPoints key (pure data).
  pluginKinds = import ../../../packages/marchyo-shell/plugin-kinds.nix;
  nativeRoles = import ../../../packages/marchyo-shell/native-roles.nix;
  pluginKindsDoc = lib.concatStringsSep ", " (
    lib.mapAttrsToList (k: key: "`${k}` (entry point `${key}`)") pluginKinds
  );

  nativeRolesDoc = lib.concatMapStringsSep ", " (r: "`${r}`") nativeRoles;

  # Raw, IFD-free spec for a CLI-added plugin: pinned git source plus manifest
  # fields. No pkgs references; marchyo-shell.nix turns
  # each spec into a built plugin via mkMarchyoShellPlugin.
  extraPluginType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Plugin manifest id (must be outside the reserved marchyo.* and omarchy.* namespaces).";
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
      keepLoaded = mkOption {
        type = types.bool;
        default = false;
        description = "The manifest's `keepLoaded`: mount a panel, menu or overlay at shell start instead of on its first summon.";
      };
      replaces = mkOption {
        type = types.listOf (types.enum nativeRoles);
        default = [ ];
        description = "Native shell roles the plugin takes over (the manifest's `replaces`), from ${nativeRolesDoc}.";
      };
      barWidget = mkOption {
        type = types.nullOr (types.attrsOf types.anything);
        default = null;
        description = "The manifest's `barWidget` block (displayName, category, allowMultiple, defaultSection, defaults, schema, settingsForm), or null.";
      };
      siblings = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [ ];
        description = "Sibling `*.manifest.json` entries: `{ manifest, id, kinds, entryPoints, ... }`, entry points relative to each manifest's directory.";
      };
    };
  };

  # Typed schema for shell.json (marchyo.shell.settings). Every level is a
  # freeform submodule, so keys the schema does not name pass through to
  # shell.json unchanged. Typed leaves default to null and are dropped from the
  # rendered file when unset (modules/home/marchyo-shell.nix), so the shell's
  # own defaults apply. Pure lib types only.
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
            centerBegin = sectionOption "centerBegin";
            center = sectionOption "center";
            centerEnd = sectionOption "centerEnd";
            right = sectionOption "right";
          };
        };
        default = { };
        description = "Bar layout: `left`, `centerBegin`, `center`, `centerEnd` and `right` widget sections. `center` stays at the middle of the bar; `centerBegin` grows leftwards from it and `centerEnd` rightwards.";
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

      clock = mkOption {
        type = types.submodule {
          freeformType = freeform;
          options.seconds = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Show live seconds in the bar clock (shell default false).";
          };
        };
        default = { };
        description = "Bar clock behaviour. Right-click on the clock flips seconds for the session.";
      };

      battery = mkOption {
        type = types.submodule {
          freeformType = freeform;
          options.percentage = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Show the charge number beside the battery glyph (shell default true).";
          };
          options.lowThreshold = mkOption {
            type = types.nullOr (types.ints.between 0 100);
            default = null;
            example = 15;
            description = ''
              Charge percentage at or below which the shell sends one critical
              low-battery notification while discharging (shell default 10).
            '';
          };
        };
        default = { };
        description = "Bar battery behaviour. Right-click on the widget flips the number for the session.";
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
        Unified Quickshell desktop shell, the default desktop shell. A single
        long-running Quickshell process renders the Jylhis-themed top bar,
        the launcher, the OSD, the panels, the notification toasts and
        centre, the lock screen, and the polkit agent, replacing hyprlock
        and hyprpolkitagent (each mutually exclusive; see
        tests/eval/marchyo-shell.nix). Defaults to on with
        `marchyo.desktop.enable` (set in modules/nixos/desktop-config.nix).
        Set it to `false` to keep the discrete stack. See shell/README.md.
      '';
    };

    diskWarnPercent = lib.mkOption {
      type = lib.types.ints.between 1 99;
      default = 10;
      example = 15;
      description = ''
        Free-space percentage of the filesystem holding the Nix store at or
        below which the `marchyo.disk` bar widget appears. Delivered to the
        shell as `health.diskWarnPercent` in shell.json.
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
        list requires a rebuild. A plugin's `replaces` list names native roles
        it takes over (see `replacedRoles`). Empty by default.
      '';
    };

    replacedRoles = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      example = {
        "panel.audio" = "acme.audio";
      };
      description = ''
        Native shell roles taken over by a declared plugin, as an attribute set
        from role to plugin id. Computed from `plugins` and `extraPlugins`
        (their `replaces` lists); empty when no plugin replaces anything. A
        role replaced by two plugins is an assertion failure. Roles are
        ${nativeRolesDoc}.
      '';
    };

    devPlugins.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Let the shell mount plugins that `marchyo plugin dev` syncs into
        `$XDG_STATE_HOME/marchyo/shell/dev-plugins`. Off by default: with it
        off the shell never reads that directory and `marchyo plugin dev`
        refuses to write to it. Dev plugins are unreviewed, unpinned code that
        runs with your privileges inside the shell, and any process of yours
        can replace them, so enable this only on a development host. Only the
        `bar-widget`, `panel`, `overlay`, `menu` and `launcher` kinds load from
        there; `service`, `daemon` and `bar` need a rebuild. Changing it needs
        a rebuild.
      '';
    };

    barPlugin = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "acme.bar";
      description = ''
        Id of a declared `bar`-kind plugin that replaces the built-in top bar.
        The built-in bar stays when this is null or the plugin fails to load.
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
        - `clock.seconds` — live seconds in the bar clock (default `false`;
          right-click the clock to flip it for the session).
        - `battery.percentage` — charge number beside the battery glyph
          (default `true`; right-click the widget to flip it for the session).
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
