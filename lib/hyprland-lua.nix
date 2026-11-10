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

  # The global shortcuts the shell registers (shell/shortcuts.json, read by
  # shell.qml too).
  shellShortcuts = map (s: s.name) (lib.importJSON ../shell/shortcuts.json);
in
rec {
  inherit mkLuaInline luaStr shellShortcuts;

  # `hl.dsp.<expr>`, e.g. dsp "window.close()".
  dsp = expr: mkLuaInline "hl.dsp.${expr}";

  # Hyprland global shortcut `marchyo:<name>`, delivered straight to the
  # running shell with no process spawned. Only names the shell registers are
  # accepted.
  global =
    name:
    if lib.elem name shellShortcuts then
      dsp "global(${luaStr "marchyo:${name}"})"
    else
      throw "hyprland-lua: '${name}' is not a shell global shortcut (shell/shortcuts.json)";

  # Shell command running dispatcher `hl.dsp.<expr>`. Under the Lua config
  # `hyprctl dispatch <arg>` evaluates <arg> as Lua, so the legacy string form
  # (`hyprctl dispatch dpms off`) is a syntax error.
  hyprDispatch = expr: "hyprctl dispatch ${lib.escapeShellArg "hl.dsp.${expr}"}";

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

  # One spelling for a Lua bind key string: modifiers upper-case and sorted,
  # the key lower-case, so "SUPER + SHIFT + CTRL + A" and
  # "SUPER + CTRL + SHIFT + a" compare equal.
  normalizeKeys =
    keys:
    let
      parts = map lib.trim (lib.splitString "+" keys);
      mods = lib.sort lib.lessThan (map lib.toUpper (lib.init parts));
    in
    lib.concatStringsSep " + " (mods ++ [ (lib.toLower (lib.last parts)) ]);

  # `hl.env("NAME", "value")`. Hyprland's Lua env takes two string arguments,
  # so entries must go through `_args`; a plain attrset such as the legacy
  # hyprlang shape `{ n = "NAME"; v = "value"; }` renders as the single-table
  # call `hl.env({ n = ..., v = ... })`, which aborts the config chunk on load
  # and silently drops every later setting. modules/home/hyprland.nix rejects
  # such entries at eval time.
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
