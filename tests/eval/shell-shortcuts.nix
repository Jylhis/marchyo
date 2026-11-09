# Shell global shortcuts: the menu, panel and toggle binds dispatch
# `hl.dsp.global("marchyo:<name>")` for a name shell/shortcuts.json registers,
# instead of spawning the CLI. Session-critical binds (lock, terminal) keep a
# direct exec.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntryText;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };

  binds =
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser {
          marchyo.desktop.enable = true;
          marchyo.shell.enable = true;
          home-manager.users.testuser.imports = [ homeManagerModules ];
        })
      ];
    }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;

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

  missing = lib.filter (keys: !(hyprHasBind binds keys (global converted.${keys}))) (
    lib.attrNames converted
  );

  lockKeyBind = lib.findFirst (
    e: (e._args or [ ]) != [ ] && builtins.head e._args == "Caps_Lock"
  ) null binds;

  rejected = builtins.tryEval (builtins.deepSeq (hlua.global "no.such.shortcut") true);
in
{
  eval-shell-shortcuts-binds-dispatch-global =
    pkgs.writeText "eval-shell-shortcuts-binds-dispatch-global"
      (
        if missing != [ ] then
          throw "FAIL: these binds do not dispatch their marchyo global shortcut: ${lib.concatStringsSep ", " missing}"
        else if
          lib.any (e: lib.hasInfix "marchyo shell" (hyprEntryText e)) (
            lib.filter (e: builtins.head (e._args or [ "" ]) != "SUPER + L") binds
          )
        then
          throw "FAIL: a bind other than the lock still spawns `marchyo shell`"
        else
          "pass"
      );

  eval-shell-shortcuts-lock-keeps-exec = pkgs.writeText "eval-shell-shortcuts-lock-keeps-exec" (
    if
      hyprHasBind binds "SUPER + L" "exec_cmd" && hyprHasBind binds "SUPER + L" "marchyo shell lock"
    then
      "pass"
    else
      throw "FAIL: SUPER+L must keep a direct exec of `marchyo shell lock`"
  );

  eval-shell-shortcuts-lock-keys-pass-through =
    pkgs.writeText "eval-shell-shortcuts-lock-keys-pass-through"
      (
        let
          opts = if lockKeyBind == null then { } else lib.elemAt lockKeyBind._args 2;
        in
        if (opts.non_consuming or false) && (opts.release or false) && (opts.ignore_mods or false) then
          "pass"
        else
          throw "FAIL: the Caps_Lock bind must be a non-consuming release bind that ignores modifiers"
      );

  eval-shell-shortcuts-unknown-name-rejected =
    pkgs.writeText "eval-shell-shortcuts-unknown-name-rejected"
      (
        if rejected.success then
          throw "FAIL: hlua.global accepted a name shell/shortcuts.json does not list"
        else if !(lib.elem "panel.audio" hlua.shellShortcuts) then
          throw "FAIL: hlua.shellShortcuts does not read shell/shortcuts.json"
        else
          "pass"
      );
}
