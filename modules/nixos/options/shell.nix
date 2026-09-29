{ lib, ... }:
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
