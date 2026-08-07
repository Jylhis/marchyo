# Application launcher (Vicinae) options.
#
# Platform-neutral declarations only — this directory is imported by
# modules/darwin/default.nix and evaluated on darwin in CI, so no `pkgs`
# references and no Linux-only types here. The implementation lives in
# modules/nixos/launcher.nix (input-server wrapper) and
# modules/home/vicinae.nix (settings + themes).
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.launcher = {
    enable = lib.mkEnableOption ''
      the Vicinae application launcher (Raycast-like, Wayland layer-shell).
      Runs `vicinae server` as a user service and binds Super+R to toggle it,
      Super+period to the emoji picker and Super+Ctrl+V to clipboard history.
      Marchyo themes it directly from the Jylhis design tokens (the Stylix
      vicinae target is disabled). Requires the desktop feature and is
      auto-enabled (`lib.mkDefault`) when `marchyo.desktop.enable` is on — set
      to `false` to opt out'';

    keybinding = mkOption {
      type = types.enum [
        "default"
        "vim"
        "emacs"
      ];
      default = "emacs";
      description = ''
        Navigation scheme inside the launcher. "vim" uses Ctrl+J/K/H/L, "emacs"
        uses Ctrl+N/P and Ctrl+Alt+B/F, and "default" resolves to the platform
        scheme (vim-style on Linux). Marchyo defaults to "emacs" to match its
        Emacs-forward defaults (`marchyo.defaults.editor`).

        Note that "emacs" makes Ctrl+N and Ctrl+P navigation keys, which collide
        with Vicinae's stock `action.new` (Ctrl+N) and `open-search-filter`
        (Ctrl+P) bindings. modules/home/vicinae.nix remaps those two whenever
        this is "emacs", so don't set the scheme through
        `programs.vicinae.settings.keybinding` directly.
      '';
    };

    inputServer.enable = lib.mkEnableOption "the Vicinae input server" // {
      default = true;
      description = ''
        Install the setcap wrapper for Vicinae's input-server helper and point
        the daemon at it. The helper injects keystrokes by writing to
        /dev/uinput, so the wrapper carries the `cap_dac_override` capability —
        a real privilege (it can bypass file permission checks). It is what
        makes emoji picking, clipboard pasting and snippet expansion type at the
        cursor rather than only reaching the clipboard.

        Set false to skip the capability. The launcher still works; the paste
        paths degrade to clipboard-only and snippet expansion does not work.
      '';
    };

    telemetry.enable = lib.mkEnableOption ''
      Vicinae's anonymous usage telemetry. Upstream enables this by default and
      posts a system-info payload to the Vicinae servers once a day, keyed by an
      install-specific ID. Marchyo defaults it off, which also suppresses the
      "What's New" telemetry notice in root search'';

    declutter =
      lib.mkEnableOption ''
        hiding the upstream housekeeping entries from root search: "Donate to
        Vicinae", "Report a Bug", "About" and "Set Theme". Set Theme is hidden
        because marchyo owns theming declaratively — a GUI theme switch is
        already overridden on the next launch''
      // {
        default = true;
      };

    settings = mkOption {
      type = types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          search_files_in_root = true;
          launcher_window.size.width = 900;
        }
      '';
      description = ''
        Extra Vicinae settings merged into `programs.vicinae.settings` for every
        marchyo user. Keys must match Vicinae's own JSON schema — note it is
        `launcher_window` (not `window`) and `font.normal.size` (not
        `font.size`); unknown keys are silently ignored by the daemon.

        Marchyo's own values are set with `lib.mkDefault`, so a plain value here
        overrides them.
      '';
    };
  };
}
