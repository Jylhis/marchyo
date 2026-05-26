{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.marchyo.emacs = {
    enable = mkEnableOption "Marchyo Emacs daemon and Hyprland integration";

    package = mkOption {
      type = types.package;
      default = pkgs.emacs-pgtk;
      defaultText = lib.literalExpression "pkgs.emacs-pgtk";
      description = ''
        Emacs package to use for the user daemon. Defaults to the
        Wayland-native pgtk build.
      '';
    };

    windmove = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Cross-WM directional focus: SUPER+ALT+H/J/K/L tries
          `windmove-*` inside Emacs first and falls through to
          `hyprctl dispatch movefocus` when at the frame edge.
          SUPER+ALT+SHIFT+H/J/K/L does the same for window swap.
        '';
      };
    };

    eventListener = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Subscribe to the Hyprland `.socket2.sock` event stream from
          Emacs and run hooks on workspace/window changes.
        '';
      };
    };

    scratchpad = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          SUPER+Z toggles an emacsclient frame titled
          `emacs-scratchpad` onto the `magic` special workspace.
        '';
      };
    };

    everywhere = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          SUPER+CTRL+E captures the focused text field into a temporary
          Emacs frame via emacs-everywhere.
        '';
      };
    };

    orgProtocol = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Register `x-scheme-handler/org-protocol` and bind
          SUPER+SHIFT+C to `(org-capture)`.
        '';
      };
    };
  };
}
