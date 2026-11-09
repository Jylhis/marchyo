# Evaluation tests for the bind table (lib/keybinds.nix) and its renderer
# (modules/home/keybinds.nix).
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers)
    withTestUser
    hyprHasBind
    hyprEntriesText
    duplicateChords
    ;

  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));
  normalizedDuplicates = duplicateChords [
    "ALT + Tab"
    "ALT + SHIFT + Tab"
  ];

  m = combo: action: { inherit combo action; };

  # Chord -> a substring of the rendered action, with every bind-contributing
  # feature on.
  chordMap = [
    (m "SUPER + L" "shell lock")
    (m "SUPER + CTRL + J" "tiled_layout")
    (m "SUPER + CTRL + SHIFT + J" "tiled_layout")
    (m "SUPER + Escape" "marchyo:menu.system")
    (m "SUPER + ALT + SPACE" "marchyo:menu")
    (m "SUPER + R" "marchyo:launcher.apps")
    (m "SUPER + CTRL + C" "marchyo:menu.capture")
    (m "SUPER + CTRL + SHIFT + X" "marchyo:menu.toggle")
    (m "SUPER + CTRL + SHIFT + H" "marchyo:menu.hardware")
    (m "SUPER + CTRL + SHIFT + T" "marchyo:menu.theme")
    (m "SUPER + F" "fileManager")
    (m "SUPER + B" "browser")
    (m "SUPER + G" "messenger")
    (m "SUPER + M" "music")
    (m "SUPER + K" "marchyo:launcher.keys")
    (m "SUPER + Q" "window.close()")
    (m "SUPER + W" "window.close()")
    (m "SUPER + ALT + D" "special:magic")
    (m "SUPER + A" ''key = "A"'')
    (m "SUPER + C" ''"CTRL SHIFT", key = "C"'')
    (m "SUPER + V" ''"CTRL SHIFT", key = "V"'')
    (m "SUPER + grave" "marchyo:overview")
    (m "SUPER + SHIFT + comma" ''monitor = "-1"'')
    (m "SUPER + SHIFT + period" ''monitor = "+1"'')
    (m "SUPER + SHIFT + CTRL + left" ''monitor = "l"'')
    (m "SUPER + SHIFT + CTRL + right" ''monitor = "r"'')
    (m "SUPER + SHIFT + CTRL + up" ''monitor = "u"'')
    (m "SUPER + SHIFT + CTRL + down" ''monitor = "d"'')
    (m "SUPER + ALT + C" "qalc")
    (m "SUPER + ALT + T" "btop")
    (m "SUPER + SHIFT + V" "marchyo:panel.audio")
    (m "SUPER + SHIFT + N" "marchyo:panel.network")
    (m "SUPER + SHIFT + B" "marchyo:panel.power")
    (m "SUPER + SHIFT + M" "marchyo:panel.monitor")
    (m "SUPER + SHIFT + Q" "marchyo:panel.controlcenter")
    (m "SUPER + CTRL + A" "wiremix")
    (m "SUPER + CTRL + W" "nmtui")
    (m "SUPER + CTRL + N" "toggle nightlight")
    (m "SUPER + CTRL + B" "marchyo:panel.bluetooth")
    (m "SUPER + CTRL + SHIFT + B" "bluetui")
    (m "SUPER + CTRL + ALT + P" "marchyo:panel.speedtest")
    (m "SUPER + CTRL + ALT + D" "marchyo:panel.dropbox")
    (m "SUPER + CTRL + D" "marchyo:panel.display")
    (m "SUPER + period" "marchyo:launcher.emoji")
    (m "SUPER + CTRL + V" "marchyo:launcher.clipboard")
    (m "SUPER + CTRL + T" "marchyo:panel.themes")
    (m "SUPER + CTRL + SHIFT + W" "marchyo:panel.backgrounds")
    (m "SUPER + CTRL + SPACE" "marchyo bg next")
    (m "SUPER + CTRL + ALT + C" "marchyo capture screenshot")
    (m "SUPER + CTRL + ALT + F" "fullscreen-desktop")
    (m "SUPER + CTRL + ALT + E" "marchyo:panel.elsewhen")
    (m "SUPER + CTRL + U" "marchyo:panel.whatsnew")
    (m "SUPER + CTRL + H" "marchyo:panel.setup")
    (m "SUPER + CTRL + ALT + G" "marchyo:panel.gallery")
    (m "SUPER + comma" "marchyo:notifications.dismiss")
    (m "SUPER + CTRL + ALT + comma" "marchyo:notifications.act")
    (m "SUPER + ALT + comma" "marchyo:notifications.keyboard")
    (m "SUPER + CTRL + comma" "marchyo:dnd")
    (m "SUPER + CTRL + SHIFT + comma" "marchyo:notifications.dismissAll")
    (m "SUPER + N" "marchyo:panel.notifications")
    (m "SUPER + ALT + return" "tmux new -A -s Work")
    (m "SUPER + ALT + L" "marchyo-cross-windmove focus r")
    (m "SUPER + ALT + SHIFT + J" "marchyo-cross-windmove move d")
    (m "SUPER + CTRL + E" "emacs-everywhere")
    (m "SUPER + SHIFT + T" "org-capture")
    (m "SUPER + CTRL + X" "dictation toggle")
  ];
  # Without the shell, the TUIs and terminal menus take the chords.
  shellOffChordMap = [
    (m "SUPER + CTRL + A" "wiremix")
    (m "SUPER + CTRL + W" "nmtui")
    (m "SUPER + CTRL + B" "bluetui")
    (m "SUPER + L" "hyprlock")
    (m "SUPER + Escape" "marchyo menu power")
    (m "SUPER + ALT + Space" "marchyo menu")
    (m "SUPER + K" "marchyo keybindings")
  ];

  hmFor =
    extra:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    }).config.home-manager.users.testuser;

  everything = {
    marchyo = {
      desktop.enable = true;
      development.enable = true;
      emacs.enable = true;
      dictation.enable = true;
      webapps.enable = true;
    };
  };
  shellOff = lib.recursiveUpdate everything {
    marchyo.shell.enable = false;
    marchyo.workspaces.perMonitor = false;
    marchyo.dictation.backend = "voxtype";
  };

  table = hm: hm.marchyo.keybinds.table;
  binds = hm: hm.wayland.windowManager.hyprland.settings.bind;

  undescribed =
    hm:
    map (e: e.combo) (
      lib.filter (e: !(lib.isString (e.description or null) && e.description != "")) (table hm)
    );
  ungrouped = hm: map (e: e.combo) (lib.filter (e: (e.group or "") == "") (table hm));

  # (combo, description) pairs the cheat sheet lists and the rendered binds
  # carry. The sheet shows number-row keycodes as digits.
  label = lib.replaceStrings (map (n: "code:${toString (n + 9)}") (lib.range 1 10)) (
    map (n: toString (lib.mod n 10)) (lib.range 1 10)
  );
  pair = combo: description: "${label combo} => ${description}";
  sheet = hm: builtins.fromJSON hm.xdg.configFile."marchyo/keybindings.json".text;
  sheetPairs =
    hm:
    map (e: pair e.combo e.description) (
      builtins.fromJSON hm.xdg.configFile."marchyo/keybindings.json".text
    );
  describedBindPairs =
    hm:
    map (b: pair (builtins.elemAt b._args 0) (builtins.elemAt b._args 2).description) (
      lib.filter (b: builtins.length b._args > 2 && (builtins.elemAt b._args 2) ? description) (binds hm)
    );
  tablePairs =
    hm: map (e: pair e.combo e.description) (lib.filter (e: !(e.hidden or false)) (table hm));

  verdict =
    name: ok: msg:
    pkgs.writeText "eval-${name}" (if ok then "pass" else throw "FAIL: ${name}: ${msg}");
in
{
  eval-keybinds-every-bind-described =
    let
      a = hmFor everything;
      b = hmFor shellOff;
      missing = undescribed a ++ undescribed b ++ ungrouped a ++ ungrouped b;
    in
    verdict "keybinds-every-bind-described" (
      missing == [ ] && builtins.length (table a) == builtins.length (binds a)
    ) "table entries without a description or group: ${lib.concatStringsSep ", " missing}";

  eval-keybinds-cheatsheet-matches-table =
    let
      check =
        hm:
        sheetPairs hm == tablePairs hm
        && lib.sort lib.lessThan (sheetPairs hm) == lib.sort lib.lessThan (describedBindPairs hm);
      a = hmFor everything;
      b = hmFor shellOff;
    in
    verdict "keybinds-cheatsheet-matches-table" (
      check a && check b
    ) "marchyo/keybindings.json differs from the bind table or the rendered binds";

  # The launcher's keys mode runs a row with `hyprctl dispatch <dispatch>`, so
  # only self-contained dispatcher expressions are exported.
  eval-keybinds-cheatsheet-dispatch =
    let
      entries = sheet (hmFor everything);
      byCombo = combo: lib.findFirst (e: e.combo == combo) null entries;
    in
    verdict "keybinds-cheatsheet-dispatch" (
      (byCombo "SUPER + ALT + SPACE").dispatch == ''hl.dsp.global("marchyo:menu")''
      && (byCombo "SUPER + C").dispatch == null
      && lib.all (e: e.dispatch == null || !(lib.hasInfix "exec_cmd(terminal" e.dispatch)) entries
    ) "the cheat sheet dispatch field is wrong";

  # Per-monitor workspace binds use keycodes; the sheet shows digits.
  eval-keybinds-cheatsheet-digit-labels =
    let
      combos = map (e: e.combo) (sheet (hmFor everything));
    in
    verdict "keybinds-cheatsheet-digit-labels" (
      lib.elem "SUPER + 1" combos
      && lib.elem "SUPER + SHIFT + ALT + 0" combos
      && !(lib.any (lib.hasInfix "code:") combos)
    ) "the cheat sheet shows keycodes instead of digits";

  # Super+C/V: Ctrl+Shift+C/V for terminals, Ctrl/Shift+Insert for every
  # other window (Emacs reads Ctrl+C and Ctrl+V as commands).
  eval-keybinds-universal-clipboard =
    let
      bs = binds (hmFor everything);
    in
    verdict "keybinds-universal-clipboard" (
      hyprHasBind bs "SUPER + C" ''"CTRL SHIFT", key = "C"''
      && hyprHasBind bs "SUPER + C" ''send_shortcut({ mods = "CTRL", key = "Insert" })''
      && hyprHasBind bs "SUPER + V" ''send_shortcut({ mods = "SHIFT", key = "Insert" })''
      && hyprHasBind bs "SUPER + X" ''send_shortcut({ mods = "CTRL", key = "X" })''
      && !(hyprHasBind bs "SUPER + C" ''mods = "CTRL", key = "C"'')
    ) "Super+C/V/X do not send the terminal and Insert chords";

  # The terminal tag follows the configured terminal (the `terminal` local).
  eval-keybinds-terminal-tag =
    let
      hm = hmFor (
        lib.recursiveUpdate everything {
          home-manager.users.testuser.wayland.windowManager.hyprland.settings.terminal._var =
            "/opt/bin/my-term --x";
        }
      );
      regex = hm.marchyo.keybinds.terminalClassRegex;
      rules = hm.wayland.windowManager.hyprland.settings.window_rule;
      tagged = lib.any (r: (r.tag or null) == "+terminal" && (r.match.class or null) == regex) rules;
    in
    verdict "keybinds-terminal-tag" (
      tagged
      && builtins.match regex "my-term" != null
      && builtins.match regex "com.mitchellh.ghostty" != null
      && builtins.match regex "org.omarchy.btop" != null
      && builtins.match regex "emacs" == null
    ) "the terminal tag rule does not cover the configured terminal: ${regex}";

  # A web app key on a marchyo chord (B, N, V are panels with the shell on)
  # loses its bind with a warning instead of double-binding.
  eval-keybinds-webapp-clash =
    let
      hm = hmFor (
        lib.recursiveUpdate everything {
          marchyo.webapps.extraApps =
            map
              (key: {
                name = "Clash ${key}";
                url = "https://example.com/${key}";
                inherit key;
              })
              [
                "B"
                "N"
                "V"
              ];
        }
      );
      dupes = normalizedDuplicates (binds hm);
      warned = lib.filter (lib.hasInfix "Clash") hm.warnings;
    in
    verdict "keybinds-webapp-clash"
      (dupes == [ ] && builtins.length warned == 3 && !(hasBindText hm "example.com"))
      "clashing web app keys: duplicates ${lib.concatStringsSep ", " dupes}, ${toString (builtins.length warned)} warnings";

  # The default web apps keep their keys: none clashes with a marchyo bind.
  eval-keybinds-default-webapps-no-clash =
    let
      hm = hmFor everything;
    in
    verdict "keybinds-default-webapps-no-clash" (
      !(lib.any (lib.hasInfix "marchyo.webapps: the key") hm.warnings)
      && hyprHasBind (binds hm) "SUPER + SHIFT + G" "github.com"
    ) "a default web app key clashes with a marchyo bind";

  # Off the desktop there is no table, no binds and no cheat-sheet file.
  eval-keybinds-desktop-off =
    let
      hm = hmFor { };
    in
    verdict "keybinds-desktop-off" (
      table hm == [ ] && !(hm.xdg.configFile ? "marchyo/keybindings.json")
    ) "desktop disabled but the bind table or the cheat-sheet file is present";

  # The layout: each chord reaches the named action.
  eval-keybinds-layout =
    let
      hm = hmFor everything;
      off = hmFor shellOff;
      missing =
        lib.filter (c: !(hyprHasBind (binds hm) c.combo c.action)) chordMap
        ++ lib.filter (c: !(hyprHasBind (binds off) c.combo c.action)) shellOffChordMap;
    in
    verdict "keybinds-layout" (missing == [ ])
      "chords off the layout: ${lib.concatMapStringsSep ", " (c: "${c.combo} -> ${c.action}") missing}";

  # No chord is bound twice, with the shell on or off.
  eval-keybinds-no-duplicate-chords =
    let
      dupes =
        normalizedDuplicates (binds (hmFor everything)) ++ normalizedDuplicates (binds (hmFor shellOff));
    in
    verdict "keybinds-no-duplicate-chords" (
      dupes == [ ]
    ) "these chords are bound more than once: ${lib.concatStringsSep ", " dupes}";
}
