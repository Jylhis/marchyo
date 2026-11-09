# Evaluation tests for marchyo.dictation.backend (superwhisper | voxtype | hex):
# backend selection, the unfree assertion, per-backend user services, the
# Alt+Space toggle and the F9 hold binds.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            marchyo.dictation.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  unfree = {
    nixpkgs.config.allowUnfree = true;
  };
  backend = name: { marchyo.dictation.backend = name; };

  hmOf = eval: eval.config.home-manager.users.testuser;
  services = eval: lib.attrNames (hmOf eval).systemd.user.services;
  binds = eval: (hmOf eval).wayland.windowManager.hyprland.settings.bind;
  failed = eval: lib.filter (a: !a.assertion) eval.config.assertions;
  hasHold = eval: hyprHasBind (binds eval) "F9" "dictation start";
  hasRelease =
    eval:
    hyprHasBind (binds eval) "F9" "dictation stop"
    && lib.hasInfix "release=true" (hyprEntriesText (binds eval));
  hasToggle = eval: hyprHasBind (binds eval) "ALT + SPACE" "dictation toggle";
  clientConfig = eval: (hmOf eval).xdg.configFile."marchyo/dictation.json".text;
  has = eval: n: lib.elem n (services eval);

  superwhisper = evalWith unfree;
  hex = evalWith (lib.recursiveUpdate unfree (backend "hex"));
  voxtype = evalWith (backend "voxtype");
  shellExec = eval: toString (hmOf eval).systemd.user.services.marchyo-shell.Service.ExecStart;
in
{
  # The default backend is Superwhisper: its daemon and setup oneshot run, the
  # package is a system package, Alt+Space toggles and F9 is a press/release pair.
  eval-dictation-backend-default-superwhisper =
    let
      cfg = superwhisper.config;
      # Without it the target orders itself after setup, which is after the
      # daemon, which is after the target: systemd drops setup at login.
      setupAfter = (hmOf superwhisper).systemd.user.services.superwhisper-setup.Unit.After;
    in
    pkgs.writeText "eval-dictation-backend-default-superwhisper" (
      if
        cfg.marchyo.dictation.backend == "superwhisper"
        && failed superwhisper == [ ]
        && has superwhisper "superwhisper"
        && has superwhisper "superwhisper-setup"
        && lib.elem "graphical-session.target" setupAfter
        && !(has superwhisper "hex")
        && !(hmOf superwhisper).services.voxtype.enable
        && lib.any (p: lib.getName p == "superwhisper") cfg.environment.systemPackages
        && !(lib.elem "input" cfg.users.users.testuser.extraGroups)
        && (builtins.fromJSON (clientConfig superwhisper)).backend == "superwhisper"
        && hasToggle superwhisper
        && hasHold superwhisper
        && hasRelease superwhisper
      then
        "pass"
      else
        throw "FAIL: the default superwhisper backend is missing its services, system package, client config or binds"
    );

  # Hex: hex.service plus the model oneshot, hold binds, no Superwhisper.
  eval-dictation-backend-hex = pkgs.writeText "eval-dictation-backend-hex" (
    if
      failed hex == [ ]
      && has hex "hex"
      && has hex "hex-model"
      && !(has hex "superwhisper")
      && !(hmOf hex).services.voxtype.enable
      && (builtins.fromJSON (clientConfig hex)).backend == "hex"
      && hasToggle hex
      && hasHold hex
      && hasRelease hex
      && !(lib.any (p: lib.getName p == "superwhisper") hex.config.environment.systemPackages)
    then
      "pass"
    else
      throw "FAIL: the hex backend is missing hex.service, hex-model, the hold binds or the client config"
  );

  # Voxtype keeps its own daemon hotkey, so no Hyprland hold binds and no
  # Superwhisper or Hex units; Alt+Space still toggles through the verb.
  eval-dictation-backend-voxtype = pkgs.writeText "eval-dictation-backend-voxtype" (
    if
      failed voxtype == [ ]
      && (hmOf voxtype).services.voxtype.enable
      && !(has voxtype "superwhisper")
      && !(has voxtype "hex")
      && (builtins.fromJSON (clientConfig voxtype)).backend == "voxtype"
      && hasToggle voxtype
      && !(hasHold voxtype)
      && lib.elem "input" voxtype.config.users.users.testuser.extraGroups
      && voxtype.config.marchyo.dictation.backend == "voxtype"
    then
      "pass"
    else
      throw "FAIL: the voxtype backend wiring is wrong (service, input group, no hold binds, toggle bind)"
  );

  # Superwhisper without unfree packages fails with a message that names the
  # fix; allowUnfree or a predicate that admits the package clears it.
  eval-dictation-backend-superwhisper-needs-unfree =
    let
      locked = evalWith { nixpkgs.config.allowUnfree = false; };
      predicate = evalWith {
        nixpkgs.config.allowUnfree = false;
        nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "superwhisper";
      };
      denied = evalWith {
        nixpkgs.config.allowUnfree = false;
        nixpkgs.config.allowUnfreePredicate = _pkg: false;
      };
      messages = lib.concatMapStrings (a: a.message) (failed locked);
    in
    pkgs.writeText "eval-dictation-backend-superwhisper-needs-unfree" (
      if
        lib.hasInfix "allowUnfree" messages
        && lib.hasInfix "voxtype" messages
        && failed predicate == [ ]
        && failed denied != [ ]
        &&
          failed (evalWith (lib.recursiveUpdate (backend "hex") { nixpkgs.config.allowUnfree = false; }))
          == [ ]
        && failed (evalWith (backend "voxtype")) == [ ]
      then
        "pass"
      else
        throw "FAIL: the superwhisper unfree assertion does not fire/clear as expected (messages: ${messages})"
    );

  # The setup oneshots are shellcheck-clean writeShellApplication scripts that build.
  eval-dictation-backend-scripts =
    let
      exec =
        eval: unit: lib.head (lib.toList (hmOf eval).systemd.user.services.${unit}.Service.ExecStart);
    in
    pkgs.runCommand "eval-dictation-backend-scripts" { } ''
      test -x ${exec superwhisper "superwhisper-setup"}
      test -x ${exec hex "hex-model"}
      touch $out
    '';

  # Dictation off: no backend unit, client config or bind, whatever the backend.
  eval-dictation-backend-disabled =
    let
      off = evalWith { marchyo.dictation.enable = false; };
    in
    pkgs.writeText "eval-dictation-backend-disabled" (
      if
        failed off == [ ]
        && !(has off "superwhisper")
        && !(has off "hex")
        && !(hasToggle off)
        && !(hmOf off).xdg.configFile ? "marchyo/dictation.json"
      then
        "pass"
      else
        throw "FAIL: dictation disabled but a backend unit, client config or bind is present"
    );

  # pushToTalk.mode = "toggle" and pushToTalk.enable = false drop the hold
  # binds on the non-voxtype backends; the toggle bind stays.
  eval-dictation-backend-hold-opt-out =
    let
      modeToggle = evalWith (
        lib.recursiveUpdate unfree { marchyo.dictation.pushToTalk.mode = "toggle"; }
      );
      off = evalWith (lib.recursiveUpdate unfree { marchyo.dictation.pushToTalk.enable = false; });
    in
    pkgs.writeText "eval-dictation-backend-hold-opt-out" (
      if !(hasHold modeToggle) && !(hasHold off) && hasToggle modeToggle && hasToggle off then
        "pass"
      else
        throw "FAIL: pushToTalk mode/enable did not drop the Hyprland hold binds"
    );

  # toggleKey = null removes the Alt+Space bind.
  eval-dictation-backend-toggle-key-null =
    let
      none = evalWith (lib.recursiveUpdate unfree { marchyo.dictation.toggleKey = null; });
    in
    pkgs.writeText "eval-dictation-backend-toggle-key-null" (
      if !(hasToggle none) && hasHold none then
        "pass"
      else
        throw "FAIL: toggleKey = null left the toggle bind (or dropped the hold bind)"
    );

  # The shell bakes the backend, so the bar indicator source differs per backend.
  eval-dictation-backend-shell-bakes-backend =
    pkgs.writeText "eval-dictation-backend-shell-bakes-backend"
      (
        if shellExec voxtype != shellExec hex && shellExec hex != shellExec superwhisper then
          "pass"
        else
          throw "FAIL: the shell package does not bake the dictation backend"
      );
}
