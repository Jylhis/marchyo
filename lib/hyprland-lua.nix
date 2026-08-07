# Helpers for building Hyprland Lua-renderer settings.
#
# Hyprland deprecated hyprlang in favour of Lua in 0.55. Home Manager's
# hyprland module renders `wayland.windowManager.hyprland.settings` for the Lua
# config type by turning each `settings.<name>` into an `hl.<name>(...)` call,
# each list element into its own call, and each `{ _args = [...] }` into a
# multi-argument call. `lib.generators.mkLuaInline` passes a value straight
# through as a raw Lua expression.
#
# Usage:
#   hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
#   wayland.windowManager.hyprland.settings.bind = [
#     (hlua.bindd "SUPER + K" "Cheat sheet" (hlua.exec "marchyo keybindings"))
#   ];
{ lib }:
let
  inherit (lib.generators) mkLuaInline;

  # Quote and escape a Nix string as a Lua string literal.
  luaStr = lib.generators.toLua { };
in
rec {
  inherit mkLuaInline luaStr;

  # `hl.dsp.<expr>`, e.g. dsp "window.close()".
  dsp = expr: mkLuaInline "hl.dsp.${expr}";

  # Exec dispatcher for a literal shell command.
  exec = cmd: dsp "exec_cmd(${luaStr cmd})";

  # Exec dispatcher for a command built as a Lua expression, used where the
  # command references one of the default-app locals declared in
  # modules/home/hyprland.nix (`terminal`, `browser`, ...).
  execLua = expr: dsp "exec_cmd(${expr})";

  # A command run in the default terminal, optionally under a specific window
  # class. The org.omarchy.* classes are matched by the floating-window tag
  # rules in modules/home/hyprland.nix, so `execInTerminal` lands a centered
  # floating window.
  execInTerminalAs = class: cmd: execLua "terminal .. ${luaStr " --class=${class} -e ${cmd}"}";
  execInTerminal = execInTerminalAs "org.omarchy.terminal";
  execInPlainTerminal = cmd: execLua "terminal .. ${luaStr " -e ${cmd}"}";

  # Keybinds. `bindd` carries a description, which the cheat sheet
  # (`marchyo keybindings`) reads back out of `hyprctl binds -j`.
  bind = keys: dispatcher: {
    _args = [
      keys
      dispatcher
    ];
  };
  bindOpts = keys: dispatcher: opts: {
    _args = [
      keys
      dispatcher
      opts
    ];
  };
  bindd =
    keys: description: dispatcher:
    bindOpts keys dispatcher { inherit description; };
  binddOpts =
    keys: description: dispatcher: opts:
    bindOpts keys dispatcher (opts // { inherit description; });

  # Build a Lua bind key string from a hyprlang-style modifier string and a
  # key, e.g. ("SUPER SHIFT", "A") -> "SUPER + SHIFT + A". Lets options that
  # already take the "SUPER SHIFT" form (marchyo.webapps.apps.*.modifiers)
  # keep their shape.
  luaKeys =
    modifiers: key:
    lib.concatStringsSep " + " (
      builtins.filter (s: s != "") (lib.splitString " " modifiers) ++ [ key ]
    );

  # `hl.env("NAME", "value")`.
  env = name: value: {
    _args = [
      name
      value
    ];
  };

  # `hl.on("<event>", function() ... end)` running one exec per command.
  onStart = commands: {
    _args = [
      "hyprland.start"
      (mkLuaInline ''
        function()
        ${lib.concatMapStrings (c: "  hl.exec_cmd(${luaStr c})\n") commands}end'')
    ];
  };
}
