{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Raw, IFD-free spec for a CLI-added plugin: a pinned git source plus the
  # manifest fields (mirrored at eval time, exactly as mkMarchyoShellPlugin's
  # args are). Kept darwin-neutral — no pkgs references — because this option
  # file is evaluated on darwin. modules/home/marchyo-shell.nix turns each spec
  # into a built plugin via pkgs.mkMarchyoShellPlugin on Linux.
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
        type = types.listOf types.str;
        description = "Manifest kinds (bar-widget|panel|overlay|menu|service).";
      };
      entryPoints = mkOption {
        type = types.attrsOf types.str;
        description = "Manifest entry points: each kind mapped to its QML file.";
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
        Vicinae (launcher) and hyprlock (lock) stay. See plans/shell.md for
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
        the shell's `plugins/` tree and listed in a generated
        `Commons/PluginIndex.qml`; a bar-widget plugin becomes referenceable from
        `marchyo.shell.settings.bar.layout` by its manifest id. Changing the list
        requires a rebuild. Empty by default.
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
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          bar.layout.right = [
            { id = "marchyo.clock"; }
            { id = "marchyo.battery"; }
          ];
          idle = { screensaver = 150; lock = 300; };
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
        - `idle.{screensaver,lock}` — idle thresholds in seconds.

        Leave empty (the default) to use the shipped bar layout unchanged.
      '';
    };
  };
}
