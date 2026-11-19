# Hotkey claims: who takes which key chord before a window sees it.
#
# A claim is `{ chord, owner, what }`. `chord` is one spelling for every
# source ("ALT + CTRL + backspace"): modifiers upper-case and sorted, the key
# lower-case. `clashes` lists the chords that more than one owner claims.
#
# Chords compare by key name. A keysym and a keycode for the same key, other
# than the number row, do not compare equal.
{ lib }:
let
  modifierAliases = {
    CONTROL = "CTRL";
    WIN = "SUPER";
    CMD = "SUPER";
    COMMAND = "SUPER";
    OPT = "ALT";
    OPTION = "ALT";
  };
  keyAliases = {
    enter = "return";
    esc = "escape";
    bksp = "backspace";
  }
  // lib.listToAttrs (
    map (n: lib.nameValuePair "code:${toString (n + 9)}" (toString (lib.mod n 10))) (lib.range 1 10)
  );

  modifierKey = key: builtins.match "(shift|control|ctrl|alt|super|meta|hyper)(_[lr])?" key != null;

  # XKB options that take a chord. Modifier-only toggles (grp:alt_shift_toggle)
  # take no chord and are not listed.
  xkbChords = {
    "grp:win_space_toggle" = "SUPER + space";
    "grp:alt_space_toggle" = "ALT + space";
    "grp:ctrl_space_toggle" = "CTRL + space";
    "terminate:ctrl_alt_bksp" = "CTRL + ALT + backspace";
  };
in
rec {
  # "Super+Space", "SUPER + SPACE" and "super+space" -> "SUPER + space".
  normalize =
    keys:
    let
      parts = lib.filter (p: p != "") (map lib.trim (lib.splitString "+" keys));
      alias = m: modifierAliases.${m} or m;
      mods = lib.sort lib.lessThan (map (m: alias (lib.toUpper m)) (lib.init parts));
      key = lib.toLower (lib.last parts);
    in
    lib.concatStringsSep " + " (mods ++ [ (keyAliases.${key} or key) ]);

  claim = owner: keys: what: {
    chord = normalize keys;
    inherit owner what;
  };

  # Table entries: `{ combo, description, ... }` (lib/keybinds.nix).
  fromTable = owner: entries: map (e: claim owner e.combo e.description) entries;

  # Rendered Hyprland binds: `{ _args = [ keys dispatcher opts? ]; }`.
  fromHyprland =
    owner: entries:
    lib.concatMap (
      e:
      let
        args = e._args or [ ];
        opts = if lib.length args > 2 then lib.elemAt args 2 else { };
      in
      lib.optional (args != [ ] && lib.isString (lib.head args)) (
        claim owner (lib.head args) (opts.description or "bind")
      )
    ) entries;

  fromXkbOptions =
    owner: options:
    lib.concatMap (o: lib.optional (xkbChords ? ${o}) (claim owner xkbChords.${o} o)) options;

  # fcitx5 settings (`i18n.inputMethod.fcitx5.settings`): the trigger keys and
  # each addon's own trigger key. A lone modifier (Shift_L) is not a chord.
  # The candidate-window keys (Tab, Up) act only while that window is open.
  fromFcitx5 =
    owner: settings:
    let
      triggers = lib.attrValues ((settings.globalOptions or { })."Hotkey/TriggerKeys" or { });
      addons = lib.mapAttrsToList (name: a: {
        inherit name;
        key = (a.globalSection or { }).TriggerKey or "";
      }) (settings.addons or { });
      chord = key: lib.isString key && key != "" && !(modifierKey (lib.toLower key));
    in
    map (key: claim owner key "trigger key") (lib.filter chord triggers)
    ++ map (a: claim owner a.key "${a.name} trigger key") (lib.filter (a: chord a.key) addons);

  # Ghostty keybinds: "alt+1=goto_tab:1", "global:ctrl+a>n=new_window". The
  # first chord of a sequence is the one a global grab hides.
  fromGhostty =
    owner: keybinds:
    lib.concatMap (
      line:
      let
        halves = lib.splitString "=" line;
        trigger = lib.last (lib.splitString ":" (lib.head (lib.splitString ">" (lib.head halves))));
        action = lib.concatStringsSep "=" (lib.tail halves);
      in
      lib.optional (lib.length halves > 1 && trigger != "") (claim owner trigger action)
    ) keybinds;

  # `[ { chord, claims } ]` for every chord with more than one owner, minus
  # the `allowed` chords.
  clashes =
    allowed: claims:
    let
      byChord = lib.groupBy (c: c.chord) claims;
      contested = lib.filterAttrs (_: cs: lib.length (lib.unique (map (c: c.owner) cs)) > 1) byChord;
      kept = removeAttrs contested (map normalize allowed);
    in
    lib.mapAttrsToList (chord: cs: {
      inherit chord;
      claims = cs;
    }) kept;

  message =
    clash:
    "Hotkey ${clash.chord} has several owners: ${
      lib.concatMapStringsSep ", " (c: "${c.owner} (${c.what})") clash.claims
    }. Change one of them, or add the chord to marchyo.keyboard.allowedHotkeyClashes.";
}
