# Shell global shortcuts: the menu, panel and toggle binds dispatch
# `hl.dsp.global("marchyo:<name>")` for a name shell/shortcuts.json registers,
# instead of spawning the CLI. Session-critical binds (lock, terminal) keep a
# direct exec.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind hyprEntryText expect;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };

  binds = c: c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;

  global = name: ''hl.dsp.global("marchyo:${name}")'';

  converted = {
    "SUPER + SHIFT + V" = "panel.audio";
    "SUPER + SHIFT + N" = "panel.network";
    "SUPER + SHIFT + B" = "panel.power";
    "SUPER + CTRL + D" = "panel.display";
    "SUPER + SHIFT + M" = "panel.monitor";
    "SUPER + SHIFT + Q" = "panel.controlcenter";
    "SUPER + CTRL + ALT + E" = "panel.elsewhen";
    "SUPER + CTRL + U" = "panel.whatsnew";
    "SUPER + CTRL + H" = "panel.setup";
    "SUPER + CTRL + ALT + G" = "panel.gallery";
    "SUPER + N" = "panel.notifications";
    "SUPER + grave" = "overview";
    "SUPER + SHIFT + SPACE" = "bar";
    "SUPER + R" = "launcher.apps";
    "SUPER + ALT + SPACE" = "menu";
    "SUPER + Escape" = "menu.system";
    "SUPER + K" = "launcher.keys";
    "SUPER + CTRL + C" = "menu.capture";
    "SUPER + CTRL + SHIFT + X" = "menu.toggle";
    "SUPER + CTRL + SHIFT + H" = "menu.hardware";
    "SUPER + CTRL + SHIFT + T" = "menu.theme";
    "SUPER + CTRL + SHIFT + W" = "panel.backgrounds";
    "SUPER + period" = "launcher.emoji";
    "SUPER + CTRL + V" = "launcher.clipboard";
    "SUPER + CTRL + B" = "panel.bluetooth";
    "SUPER + CTRL + ALT + P" = "panel.speedtest";
    "SUPER + CTRL + ALT + D" = "panel.dropbox";
    "SUPER + CTRL + T" = "panel.themes";
    "SUPER + comma" = "notifications.dismiss";
    "SUPER + CTRL + ALT + comma" = "notifications.act";
    "SUPER + ALT + comma" = "notifications.keyboard";
    "SUPER + CTRL + SHIFT + comma" = "notifications.dismissAll";
    "SUPER + CTRL + comma" = "dnd";
    "Caps_Lock" = "lockKeys";
    "Num_Lock" = "lockKeys";
  };

  rejected = builtins.tryEval (builtins.deepSeq (hlua.global "no.such.shortcut") true);
in
{
  refs.desktop = {
    eval-shell-shortcuts-binds-dispatch-global =
      c:
      let
        missing = lib.filter (keys: !(hyprHasBind (binds c) keys (global converted.${keys}))) (
          lib.attrNames converted
        );
      in
      if missing != [ ] then
        "these binds do not dispatch their marchyo global shortcut: ${lib.concatStringsSep ", " missing}"
      else if
        lib.any (e: lib.hasInfix "marchyo shell" (hyprEntryText e)) (
          lib.filter (e: builtins.head (e._args or [ "" ]) != "SUPER + L") (binds c)
        )
      then
        "a bind other than the lock still spawns `marchyo shell`"
      else
        true;

    eval-shell-shortcuts-lock-keeps-exec =
      c:
      expect (
        hyprHasBind (binds c) "SUPER + L" "exec_cmd"
        && hyprHasBind (binds c) "SUPER + L" "marchyo shell lock"
      ) "SUPER+L must keep a direct exec of `marchyo shell lock`";

    eval-shell-shortcuts-lock-keys-pass-through =
      c:
      let
        lockKeyBind = lib.findFirst (
          e: (e._args or [ ]) != [ ] && builtins.head e._args == "Caps_Lock"
        ) null (binds c);
        opts = if lockKeyBind == null then { } else lib.elemAt lockKeyBind._args 2;
      in
      expect (
        (opts.non_consuming or false) && (opts.release or false) && (opts.ignore_mods or false)
      ) "the Caps_Lock bind must be a non-consuming release bind that ignores modifiers";
  };

  checks.eval-shell-shortcuts-unknown-name-rejected =
    helpers.assertTest "shell-shortcuts-unknown-name-rejected"
      (!rejected.success && lib.elem "panel.audio" hlua.shellShortcuts)
      "hlua.global accepted a name shell/shortcuts.json does not list, or hlua.shellShortcuts does not read it";
}
