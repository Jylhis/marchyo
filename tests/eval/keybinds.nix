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
    "F9"
  ];

  m = combo: action: { inherit combo action; };

  # Omarchy 4.5 chord -> a substring of the rendered action, with every
  # bind-contributing feature on.
  chordMap = [
    (m "SUPER + L" "tiled_layout")
    (m "SUPER + ALT + L" "tiled_layout")
    (m "SUPER + CTRL + L" "shell lock")
    (m "SUPER + Escape" "marchyo:menu.system")
    (m "SUPER + SPACE" "marchyo:menu")
    (m "SUPER + ALT + SPACE" "marchyo:launcher.apps")
    (m "SUPER + CTRL + C" "marchyo:menu.capture")
    (m "SUPER + CTRL + X" "marchyo:menu.toggle")
    (m "SUPER + CTRL + SHIFT + H" "marchyo:menu.hardware")
    (m "SUPER + CTRL + SHIFT + T" "marchyo:menu.theme")
    (m "SUPER + SHIFT + F" "fileManager")
    (m "SUPER + SHIFT + B" "browser")
    (m "SUPER + SHIFT + G" "messenger")
    (m "SUPER + K" "marchyo:launcher.keys")
    (m "SUPER + Q" "window.close()")
    (m "SUPER + W" "window.close()")
    (m "SUPER + M" "special:magic")
    (m "SUPER + A" ''key = "A"'')
    (m "SUPER + C" ''"CTRL SHIFT", key = "C"'')
    (m "SUPER + V" ''"CTRL SHIFT", key = "V"'')
    (m "SUPER + CTRL + grave" "marchyo:overview")
    (m "SUPER + SHIFT + CTRL + left" ''monitor = "l"'')
    (m "SUPER + SHIFT + CTRL + right" ''monitor = "r"'')
    (m "SUPER + SHIFT + CTRL + up" ''monitor = "u"'')
    (m "SUPER + SHIFT + CTRL + down" ''monitor = "d"'')
    (m "SUPER + SHIFT + M" "music")
    (m "SUPER + SHIFT + Q" "qalc")
    (m "SUPER + SHIFT + T" "btop")
    (m "SUPER + CTRL + A" "marchyo:panel.audio")
    (m "SUPER + CTRL + B" "marchyo:panel.bluetooth")
    (m "SUPER + CTRL + SHIFT + B" "bluetui")
    (m "SUPER + CTRL + ALT + P" "marchyo:panel.speedtest")
    (m "SUPER + CTRL + ALT + D" "marchyo:panel.dropbox")
    (m "SUPER + CTRL + D" "marchyo:panel.display")
    (m "SUPER + CTRL + N" "marchyo:panel.network")
    (m "SUPER + CTRL + P" "marchyo:panel.power")
    (m "SUPER + CTRL + M" "marchyo:panel.monitor")
    (m "SUPER + CTRL + O" "marchyo:panel.controlcenter")
    (m "SUPER + CTRL + E" "marchyo:launcher.emoji")
    (m "SUPER + CTRL + V" "marchyo:launcher.clipboard")
    (m "SUPER + CTRL + T" "marchyo:panel.themes")
    (m "SUPER + CTRL + SHIFT + W" "marchyo:panel.backgrounds")
    (m "SUPER + CTRL + W" "marchyo bg next")
    (m "SUPER + CTRL + ALT + C" "marchyo capture screenshot")
    (m "SUPER + CTRL + ALT + F" "fullscreen-desktop")
    (m "SUPER + CTRL + ALT + E" "marchyo:panel.elsewhen")
    (m "SUPER + CTRL + U" "marchyo:panel.whatsnew")
    (m "SUPER + CTRL + H" "marchyo:panel.setup")
    (m "SUPER + CTRL + ALT + G" "marchyo:panel.gallery")
    (m "SUPER + comma" "marchyo:notifications.act")
    (m "SUPER + ALT + comma" "marchyo:notifications.dismissOne")
    (m "SUPER + CTRL + comma" "marchyo:notifications.keyboard")
    (m "SUPER + CTRL + ALT + comma" "marchyo:notifications.silence")
    (m "SUPER + SHIFT + comma" "marchyo:notifications.dismissAll")
    (m "SUPER + SHIFT + ALT + comma" "marchyo:panel.notifications")
    (m "SUPER + ALT + return" "tmux new -A -s Work")
    (m "SUPER + CTRL + ALT + L" "marchyo-cross-windmove focus r")
    (m "SUPER + SHIFT + ALT + E" "emacs-everywhere")
    (m "SUPER + CTRL + ALT + O" "org-capture")
    (m "ALT + SPACE" "dictation toggle")
    (m "F9" "dictation start")
    (m "F9" "dictation stop")
  ];
  # Without the shell, the panel chords open the TUIs.
  shellOffChordMap = [
    (m "SUPER + CTRL + A" "wiremix")
    (m "SUPER + CTRL + N" "nmtui")
    (m "SUPER + CTRL + L" "hyprlock")
    (m "SUPER + Escape" "marchyo menu power")
    (m "SUPER + ALT + Space" "marchyo menu")
    (m "SUPER + K" "marchyo keybindings")
  ];
  legacyChordMap = [
    (m "SUPER + L" "shell lock")
    (m "SUPER + M" "music")
    (m "SUPER + grave" "marchyo:overview")
    (m "SUPER + CTRL + N" "toggle nightlight")
    (m "SUPER + CTRL + W" "nmtui")
    (m "SUPER + CTRL + A" "wiremix")
    (m "SUPER + SHIFT + V" "marchyo:panel.audio")
    (m "SUPER + SHIFT + Q" "marchyo:panel.controlcenter")
    (m "SUPER + comma" "marchyo:notifications.dismiss")
    (m "SUPER + N" "marchyo:panel.notifications")
    (m "SUPER + period" "marchyo:launcher.emoji")
    (m "SUPER + ALT + L" "marchyo-cross-windmove focus r")
    (m "SUPER + F" "fileManager")
    (m "SUPER + B" "browser")
    (m "SUPER + G" "messenger")
    (m "SUPER + ALT + SPACE" "marchyo:menu")
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
      (byCombo "SUPER + SPACE").dispatch == ''hl.dsp.global("marchyo:menu")''
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
  # other window (Emacs reads Ctrl+C and Ctrl+V as commands). The legacy
  # layout keeps the plain Insert binds.
  eval-keybinds-universal-clipboard =
    let
      modern = binds (hmFor everything);
      old = binds (hmFor (lib.recursiveUpdate everything { marchyo.keyboard.legacyBinds = true; }));
      oldBind =
        chord: expr: description:
        lib.any (
          b:
          builtins.head b._args == chord
          && (builtins.elemAt b._args 1).expr or null == "hl.dsp.${expr}"
          && (builtins.elemAt b._args 2).description or null == description
        ) old;
    in
    verdict "keybinds-universal-clipboard" (
      hyprHasBind modern "SUPER + C" ''"CTRL SHIFT", key = "C"''
      && hyprHasBind modern "SUPER + C" ''send_shortcut({ mods = "CTRL", key = "Insert" })''
      && hyprHasBind modern "SUPER + V" ''send_shortcut({ mods = "SHIFT", key = "Insert" })''
      && !(hyprHasBind modern "SUPER + C" ''mods = "CTRL", key = "C"'')
      && oldBind "SUPER + C" ''send_shortcut({ mods = "CTRL", key = "Insert" })'' "Copy"
      && oldBind "SUPER + V" ''send_shortcut({ mods = "SHIFT", key = "Insert" })'' "Paste"
      && oldBind "SUPER + X" ''send_shortcut({ mods = "CTRL", key = "X" })'' "Cut"
    ) "Super+C/V/X do not send the terminal and Insert chords, or the legacy binds changed";

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

  # A web app key on a marchyo chord (B, N, V are the legacy panels with the
  # shell on) loses its bind with a warning instead of double-binding.
  eval-keybinds-webapp-clash =
    let
      hm = hmFor (
        lib.recursiveUpdate everything {
          marchyo.keyboard.legacyBinds = true;
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

  # Off the desktop there is no table, no binds and no cheat-sheet file.
  eval-keybinds-desktop-off =
    let
      hm = hmFor { };
    in
    verdict "keybinds-desktop-off" (
      table hm == [ ] && !(hm.xdg.configFile ? "marchyo/keybindings.json")
    ) "desktop disabled but the bind table or the cheat-sheet file is present";

  # The Omarchy 4.5 layout: each chord reaches the named action.
  eval-keybinds-omarchy-45-layout =
    let
      hm = hmFor everything;
      off = hmFor shellOff;
      missing =
        lib.filter (c: !(hyprHasBind (binds hm) c.combo c.action)) chordMap
        ++ lib.filter (c: !(hyprHasBind (binds off) c.combo c.action)) shellOffChordMap;
      forbidden = lib.filter (s: hasBindText hm s) [
        "toggle nightlight"
        "notifications.dismiss\""
        "marchyo:dnd"
      ];
    in
    verdict "keybinds-omarchy-45-layout" (missing == [ ] && forbidden == [ ]) (
      "chords off the 4.5 layout: "
      + lib.concatMapStringsSep ", " (c: "${c.combo} -> ${c.action}") missing
      + "; binds that 4.5 removes: ${lib.concatStringsSep ", " forbidden}"
    );

  # marchyo.keyboard.legacyBinds brings back the pre-4.5 chords.
  eval-keybinds-legacy-layout =
    let
      hm = hmFor (lib.recursiveUpdate everything { marchyo.keyboard.legacyBinds = true; });
      missing = lib.filter (c: !(hyprHasBind (binds hm) c.combo c.action)) legacyChordMap;
    in
    verdict "keybinds-legacy-layout" (
      missing == [ ] && !(hyprHasBind (binds hm) "SUPER + CTRL + L" "lock")
    ) "legacy chords missing: ${lib.concatMapStringsSep ", " (c: "${c.combo} -> ${c.action}") missing}";

  # The legacy layout binds no chord twice either.
  eval-keybinds-legacy-no-duplicate-chords =
    let
      dupes = normalizedDuplicates (
        binds (hmFor (lib.recursiveUpdate everything { marchyo.keyboard.legacyBinds = true; }))
      );
    in
    verdict "keybinds-legacy-no-duplicate-chords" (
      dupes == [ ]
    ) "legacy layout binds these chords more than once: ${lib.concatStringsSep ", " dupes}";
}
