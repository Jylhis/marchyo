# Command menu entries (platform-neutral declaration). modules/home/menu.nix
# renders them to ~/.config/marchyo/menu.json for the shell; modules/nixos/menu.nix
# defines the default tree and asserts the tree is well formed.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  entry = _: {
    options = {
      label = mkOption {
        type = types.str;
        description = "Text shown for the entry.";
      };
      icon = mkOption {
        type = types.str;
        default = "";
        description = "A themed icon name or a glyph. Empty shows no icon.";
      };
      order = mkOption {
        type = types.int;
        default = 100;
        description = "Sort key among siblings; equal orders sort by label.";
      };
      action = mkOption {
        type = types.enum [
          "submenu"
          "exec"
          "terminal"
          "launcher"
          "provider"
        ];
        default = "submenu";
        description = ''
          What selecting the entry does. `submenu` opens the entries whose id
          is a child of this one. `exec` runs `target` with `sh -c`, detached,
          then closes the menu. `terminal` runs `target` in a floating
          terminal. `launcher` opens the shell launcher in the mode named by
          `target` (apps, emoji, clipboard, theme or keys). `provider` fills
          the submenu from the data source named by `provider`.
        '';
      };
      target = mkOption {
        type = types.str;
        default = "";
        description = "The shell command (exec, terminal) or launcher mode (launcher).";
      };
      provider = mkOption {
        type = types.nullOr (
          types.enum [
            "apps"
            "themes"
            "wallpapers"
            "fonts"
            "power-profiles"
            "languages"
            "agents"
          ]
        );
        default = null;
        description = "The data source of a `provider` entry. Must be null for other actions.";
      };
      aliases = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra search words for the entry.";
      };
      description = mkOption {
        type = types.str;
        default = "";
        description = "Secondary text shown under the label.";
      };
      when = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          A shell command run with `sh -c`. Exit status 0 shows the entry; any
          other status hides it. Null always shows the entry.
        '';
      };
      checked = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          A shell command run with `sh -c`. Exit status 0 shows a check mark on
          the entry. Null never shows one.
        '';
      };
      disabled = mkOption {
        type = types.bool;
        default = false;
        description = "Hide the entry (and its children) without removing it.";
      };
    };
  };
in
{
  options.marchyo.menu.entries = mkOption {
    type = types.attrsOf (types.submodule entry);
    default = { };
    description = ''
      Entries of the shell command menu, keyed by dotted id. The parent of
      `a.b.c` is `a.b`; an id without a dot is a child of the root. Every parent
      must exist as an entry. The default tree (lib/menu-entries.nix) is defined
      per field at default priority, so a definition adds entries and overrides
      single fields of default ones. A user can also overlay entries at runtime in
      `~/.config/marchyo/menu.local.json`.
    '';
    example = lib.literalExpression ''
      {
        "capture.custom" = {
          label = "Custom";
          action = "exec";
          target = "true";
        };
      }
    '';
  };
}
